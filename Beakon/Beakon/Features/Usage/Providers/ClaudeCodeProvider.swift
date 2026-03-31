//
//  ClaudeCodeProvider.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import os

final class ClaudeCodeProvider: UsageProvider {
    let id = "claude-code"
    let name = "Claude Code"
    let iconName = "terminal"

    private let logger = Logger(subsystem: "com.beakon", category: "ClaudeCode")
    private let keychain = KeychainService()
    private let sessionWindowHours = 5.0

    private var cachedToken: String?
    private var cachedCreds: OAuthCredentials.OAuthData?
    private var keychainRead = false
    private var lastSuccessfulLimits: OAuthLimitsResult?
    private var lastAPICallTime: Date?

    private var claudeDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }
    private var beakonCachePath: URL { claudeDir.appendingPathComponent(".beakon_credentials_cache.json") }
    private var limitsCachePath: URL { claudeDir.appendingPathComponent(".beakon_limits_cache.json") }

    var isConfigured: Bool {
        getToken() != nil
    }

    func configure(with credentials: ProviderCredentials) {}

    func fetchUsage() async throws -> UsageSnapshot {
        let parsed = try parseHistory()
        let hasCreds = getToken() != nil
        let freshLimits = await fetchOAuthLimits()

        // Cache successful results to memory + disk; use cached on rate limit
        if let freshLimits {
            lastSuccessfulLimits = freshLimits
            saveLimitsCache(freshLimits)
        }
        let limits = freshLimits ?? lastSuccessfulLimits ?? loadLimitsCache()

        let status: AuthStatus = hasCreds ? .authenticated : .notAuthenticated(hint: "Run claude to authenticate")

        return UsageSnapshot(
            totalInputTokens: parsed.today.messageCount,
            totalOutputTokens: parsed.today.sessionCount,
            totalCostUSD: 0,
            periodStart: Calendar.current.startOfDay(for: Date()),
            periodEnd: Date(),
            modelBreakdown: [],
            dailyMessageCounts: parsed.dailyCounts,
            sessionInfo: parsed.sessionInfo,
            weeklyMessageCount: parsed.weeklyMessageCount,
            projectBreakdown: parsed.projects,
            limits: limits?.limits,
            planName: limits?.planName,
            authStatus: status
        )
    }

    // MARK: - OAuth credentials

    private struct OAuthCredentials: Codable {
        let claudeAiOauth: OAuthData?

        struct OAuthData: Codable {
            let accessToken: String
            let refreshToken: String
            let expiresAt: Int64
            let subscriptionType: String?
            let rateLimitTier: String?
        }
    }

    /// Get a working access token. Priority: memory → file → cache → keychain (once).
    private func getToken() -> String? {
        if let t = cachedToken { return t }
        if let creds = readCredsFromFile() { cachedToken = creds.accessToken; cachedCreds = creds; return creds.accessToken }
        if let creds = readCredsFromCache() { cachedToken = creds.accessToken; cachedCreds = creds; return creds.accessToken }
        if !keychainRead, let creds = readCredsFromKeychain() {
            keychainRead = true
            cachedToken = creds.accessToken; cachedCreds = creds
            writeCredsToCache(creds) // persist so we don't hit Keychain again
            return creds.accessToken
        }
        return nil
    }

    /// Force re-read from file/keychain (after 401)
    private func refreshCredentials() -> String? {
        cachedToken = nil
        if let creds = readCredsFromFile() { cachedToken = creds.accessToken; cachedCreds = creds; writeCredsToCache(creds); return creds.accessToken }
        if let creds = readCredsFromKeychain() { cachedToken = creds.accessToken; cachedCreds = creds; writeCredsToCache(creds); return creds.accessToken }
        return nil
    }

    private func readCredsFromFile() -> OAuthCredentials.OAuthData? {
        let path = claudeDir.appendingPathComponent(".credentials.json")
        guard let data = try? Data(contentsOf: path),
              let creds = try? JSONDecoder().decode(OAuthCredentials.self, from: data) else { return nil }
        return creds.claudeAiOauth
    }

    private func readCredsFromCache() -> OAuthCredentials.OAuthData? {
        guard let data = try? Data(contentsOf: beakonCachePath),
              let creds = try? JSONDecoder().decode(OAuthCredentials.self, from: data) else { return nil }
        return creds.claudeAiOauth
    }

    private func readCredsFromKeychain() -> OAuthCredentials.OAuthData? {
        // Use `security` CLI instead of SecItemCopyMatching — avoids repeated macOS password prompts
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonString = String(data: output, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let jsonData = jsonString.data(using: .utf8),
              let creds = try? JSONDecoder().decode(OAuthCredentials.self, from: jsonData) else { return nil }
        return creds.claudeAiOauth
    }

    private func writeCredsToCache(_ creds: OAuthCredentials.OAuthData) {
        let json: [String: Any] = ["claudeAiOauth": [
            "accessToken": creds.accessToken, "refreshToken": creds.refreshToken,
            "expiresAt": creds.expiresAt,
            "subscriptionType": creds.subscriptionType as Any,
            "rateLimitTier": creds.rateLimitTier as Any
        ]]
        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]) {
            try? data.write(to: beakonCachePath)
        }
    }

    // MARK: - Limits disk cache

    private func saveLimitsCache(_ result: OAuthLimitsResult) {
        let items = result.limits.items.map { item -> [String: Any] in
            ["title": item.title, "percent": item.percent, "detail": item.detail,
             "style": item.style == .spending ? "spending" : "bar"]
        }
        let json: [String: Any] = [
            "items": items,
            "planName": result.planName as Any,
            "savedAt": Date().timeIntervalSince1970
        ]
        if let data = try? JSONSerialization.data(withJSONObject: json) {
            try? data.write(to: limitsCachePath)
        }
    }

    private func loadLimitsCache() -> OAuthLimitsResult? {
        guard let data = try? Data(contentsOf: limitsCachePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]],
              // Only use cache if less than 30 minutes old
              let savedAt = json["savedAt"] as? Double,
              Date().timeIntervalSince1970 - savedAt < 1800 else { return nil }

        let limitItems = items.compactMap { item -> ProviderLimits.LimitItem? in
            guard let title = item["title"] as? String,
                  let percent = item["percent"] as? Int,
                  let detail = item["detail"] as? String else { return nil }
            let style: ProviderLimits.LimitItem.Style = (item["style"] as? String) == "spending" ? .spending : .bar
            return .init(title: title, percent: percent, detail: detail, style: style)
        }
        guard !limitItems.isEmpty else { return nil }

        return OAuthLimitsResult(
            limits: ProviderLimits(items: limitItems),
            planName: json["planName"] as? String
        )
    }

    // MARK: - OAuth Usage API

    private struct OAuthLimitsResult {
        let limits: ProviderLimits
        let planName: String?
    }

    private func fetchOAuthLimits() async -> OAuthLimitsResult? {
        guard let token = getToken() else {
            logger.info("No token found — skipping OAuth usage fetch")
            return nil
        }

        // Rate limit cooldown — don't call API more than once per 60s
        if let lastCall = lastAPICallTime, Date().timeIntervalSince(lastCall) < 60 {
            logger.info("API cooldown active — using cached data")
            return nil
        }
        lastAPICallTime = Date()

        logger.info("Fetching OAuth usage...")
        if let result = await callUsageAPI(token: token) { return result }

        // 401/403 → re-read credentials (Claude Code may have refreshed)
        logger.info("First attempt failed — re-reading credentials")
        if let freshToken = refreshCredentials(), freshToken != token {
            if let result = await callUsageAPI(token: freshToken) { return result }
        }

        // Last resort: OAuth refresh
        logger.info("Trying OAuth token refresh")
        if let rt = cachedCreds?.refreshToken,
           let refreshed = await oauthRefresh(rt),
           let result = await callUsageAPI(token: refreshed) {
            return result
        }

        return nil
    }

    private func callUsageAPI(token: String) async -> OAuthLimitsResult? {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.1.69", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else {
                logger.warning("OAuth usage API returned \(code)")
                return nil
            }
            return parseUsageResponse(data, subscriptionType: cachedCreds?.subscriptionType, rateLimitTier: cachedCreds?.rateLimitTier)
        } catch {
            logger.error("OAuth usage fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func parseUsageResponse(_ data: Data, subscriptionType: String?, rateLimitTier: String?) -> OAuthLimitsResult? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        var items: [ProviderLimits.LimitItem] = []

        // Session (5-hour window)
        if let fiveHour = json["five_hour"] as? [String: Any],
           let utilization = fiveHour["utilization"] as? Int {
            let resetsAt = fiveHour["resets_at"] as? String
            let resetDetail = formatResetTime(resetsAt)
            items.append(.init(title: "Session", percent: utilization, detail: resetDetail))
        }

        // Weekly (7-day window)
        if let sevenDay = json["seven_day"] as? [String: Any],
           let utilization = sevenDay["utilization"] as? Int {
            let resetsAt = sevenDay["resets_at"] as? String
            let resetDetail = formatResetTime(resetsAt)
            items.append(.init(title: "Weekly", percent: utilization, detail: resetDetail))
        }

        // Extra usage / on-demand credits
        if let extraUsage = json["extra_usage"] as? [String: Any] {
            let usedCents = extraUsage["used_credits"] as? Double ?? 0
            let limitCents = extraUsage["monthly_limit"] as? Double ?? 0
            if limitCents > 0 {
                let percent = min(100, Int((usedCents / limitCents) * 100))
                let detail = String(format: "$%.2f / $%.0f", usedCents / 100, limitCents / 100)
                items.append(.init(title: "Extra Usage", percent: percent, detail: detail, style: .spending))
            }
        }

        guard !items.isEmpty else { return nil }

        let planName = formatPlanName(subscriptionType: subscriptionType, tier: rateLimitTier)

        return OAuthLimitsResult(
            limits: ProviderLimits(items: items),
            planName: planName
        )
    }

    private func formatPlanName(subscriptionType: String?, tier: String?) -> String? {
        guard let sub = subscriptionType else { return nil }
        // e.g. "max" → "Max", "pro" → "Pro"
        var name = sub.capitalized
        // Extract multiplier from tier, e.g. "default_claude_max_5x" → "5x"
        if let tier, let range = tier.range(of: #"\d+x"#, options: .regularExpression) {
            name += " \(tier[range])"
        }
        return name
    }

    private func formatResetTime(_ iso8601: String?) -> String {
        guard let iso = iso8601 else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "" }

        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "Resetting..." }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours >= 24 {
            let days = hours / 24
            let remHours = hours % 24
            return "Resets in \(days)d \(remHours)h"
        } else if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }

    // MARK: - Token refresh

    /// OAuth token refresh — returns new access token, updates caches
    private func oauthRefresh(_ refreshToken: String) async -> String? {
        guard let url = URL(string: "https://platform.claude.com/v1/oauth/token") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/2.1.69", forHTTPHeaderField: "User-Agent")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
            "scope": "user:profile user:inference user:sessions:claude_code user:mcp_servers"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String else {
            logger.warning("Token refresh failed")
            return nil
        }

        let newRefreshToken = json["refresh_token"] as? String ?? refreshToken
        let expiresIn = json["expires_in"] as? Int64 ?? 3600
        let newExpiresAt = Int64(Date().timeIntervalSince1970 * 1000) + (expiresIn * 1000)

        let newCreds = OAuthCredentials.OAuthData(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
            expiresAt: newExpiresAt,
            subscriptionType: cachedCreds?.subscriptionType,
            rateLimitTier: cachedCreds?.rateLimitTier
        )

        cachedToken = newAccessToken
        cachedCreds = newCreds
        writeCredsToCache(newCreds)

        return newAccessToken
    }

    // MARK: - History parsing (local stats)

    private struct ParsedHistory {
        var today: DayStats
        var dailyCounts: [DailyCount]
        var projects: [UsageSnapshot.ProjectUsage]
        var sessionInfo: SessionInfo?
        var weeklyMessageCount: Int
    }

    private struct DayStats {
        var messageCount = 0
        var sessionCount = 0
    }

    private func parseHistory() throws -> ParsedHistory {
        let url = claudeDir.appendingPathComponent("history.jsonl")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ParsedHistory(today: DayStats(), dailyCounts: [], projects: [], weeklyMessageCount: 0)
        }

        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            return ParsedHistory(today: DayStats(), dailyCounts: [], projects: [], weeklyMessageCount: 0)
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        let todayMs = Int(todayStart.timeIntervalSince1970) * 1000
        let weekMs = Int(sevenDaysAgo.timeIntervalSince1970) * 1000
        let sessionWindowStart = now.addingTimeInterval(-sessionWindowHours * 3600)
        let sessionWindowMs = Int(sessionWindowStart.timeIntervalSince1970) * 1000

        var todaySessions = Set<String>()
        var todayMessages = 0
        var weeklyMessages = 0
        var dailyMap: [String: Int] = [:]
        var projectCounts: [String: Int] = [:]
        var sessionMessages = 0
        var sessionFirstMessageDate: Date?

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let lines = content.components(separatedBy: .newlines)
        for line in lines.reversed() {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let entry = try? JSONDecoder().decode(HistoryEntry.self, from: lineData) else { continue }

            if entry.timestamp < weekMs { break }

            let entryDate = Date(timeIntervalSince1970: Double(entry.timestamp) / 1000.0)
            let dayKey = dateFormatter.string(from: entryDate)
            dailyMap[dayKey, default: 0] += 1
            weeklyMessages += 1

            if entry.timestamp >= sessionWindowMs {
                sessionMessages += 1
                sessionFirstMessageDate = entryDate
            }

            if entry.timestamp >= todayMs {
                todayMessages += 1
                todaySessions.insert(entry.sessionId)
                if let project = entry.project {
                    let name = project.split(separator: "/").last.map(String.init) ?? "unknown"
                    projectCounts[name, default: 0] += 1
                }
            }
        }

        var dailyCounts: [DailyCount] = []
        for i in (0..<7).reversed() {
            let day = calendar.date(byAdding: .day, value: -i, to: todayStart) ?? todayStart
            dailyCounts.append(DailyCount(date: day, count: dailyMap[dateFormatter.string(from: day)] ?? 0))
        }

        var sessionInfo: SessionInfo?
        if let firstMsg = sessionFirstMessageDate, sessionMessages > 0 {
            sessionInfo = SessionInfo(startedAt: firstMsg, messageCount: sessionMessages,
                                     resetsAt: firstMsg.addingTimeInterval(sessionWindowHours * 3600))
        }

        let projects = projectCounts.sorted { $0.value > $1.value }
            .map { UsageSnapshot.ProjectUsage(name: $0.key, messageCount: $0.value) }

        return ParsedHistory(today: DayStats(messageCount: todayMessages, sessionCount: todaySessions.count),
                            dailyCounts: dailyCounts, projects: projects,
                            sessionInfo: sessionInfo, weeklyMessageCount: weeklyMessages)
    }
}

// MARK: - Local file models

private struct HistoryEntry: Codable {
    let timestamp: Int
    let sessionId: String
    let display: String?
    let project: String?
}
