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

    // In-memory cache to avoid repeated Keychain prompts
    private var cachedCredentials: OAuthCredentials.OAuthData?
    private var credentialsChecked = false

    private var claudeDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    var isConfigured: Bool {
        if cachedCredentials != nil { return true }
        if credentialsChecked { return false }
        let creds = loadCredentialsFromDisk()
        cachedCredentials = creds
        credentialsChecked = true
        return creds != nil
    }

    func configure(with credentials: ProviderCredentials) {}

    func fetchUsage() async throws -> UsageSnapshot {
        let parsed = try parseHistory()

        // Try to fetch live limits from OAuth API
        let limits = await fetchOAuthLimits()

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
            authStatus: limits != nil ? .authenticated : .notAuthenticated(hint: "Run claude to authenticate")
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

    private func loadCredentials() -> OAuthCredentials.OAuthData? {
        if let cached = cachedCredentials { return cached }
        let creds = loadCredentialsFromDisk()
        cachedCredentials = creds
        return creds
    }

    private var beakonCachePath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.beakon_credentials_cache.json")
    }

    private func loadCredentialsFromDisk() -> OAuthCredentials.OAuthData? {
        // 1. Try Claude Code's own file
        let filePath = claudeDir.appendingPathComponent(".credentials.json")
        if let data = try? Data(contentsOf: filePath),
           let creds = try? JSONDecoder().decode(OAuthCredentials.self, from: data),
           let oauth = creds.claudeAiOauth {
            return oauth
        }

        // 2. Try Beakon's local cache (written after first Keychain read)
        if let data = try? Data(contentsOf: beakonCachePath),
           let creds = try? JSONDecoder().decode(OAuthCredentials.self, from: data),
           let oauth = creds.claudeAiOauth {
            return oauth
        }

        // 3. Last resort: Keychain (triggers macOS prompt once, then we cache it)
        if let json = try? keychain.loadExternal(service: "Claude Code-credentials"),
           let data = json.data(using: .utf8),
           let creds = try? JSONDecoder().decode(OAuthCredentials.self, from: data),
           let oauth = creds.claudeAiOauth {
            // Cache locally so we never hit Keychain again
            try? data.write(to: beakonCachePath)
            return oauth
        }

        return nil
    }

    // MARK: - OAuth Usage API

    private struct OAuthLimitsResult {
        let limits: ProviderLimits
        let planName: String?
    }

    private func fetchOAuthLimits() async -> OAuthLimitsResult? {
        guard var creds = loadCredentials() else { return nil }

        // Refresh token if expired (with 5 min buffer)
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        if creds.expiresAt < nowMs + 300_000 {
            if let refreshed = await refreshToken(creds.refreshToken) {
                creds = refreshed
            } else {
                logger.warning("Token expired and refresh failed")
                return nil
            }
        }

        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("Beakon/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                if let refreshed = await refreshToken(creds.refreshToken) {
                    return await fetchWithToken(refreshed.accessToken)
                }
                return nil
            }

            return parseUsageResponse(data, subscriptionType: creds.subscriptionType, rateLimitTier: creds.rateLimitTier)
        } catch {
            logger.error("OAuth usage fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchWithToken(_ token: String) async -> OAuthLimitsResult? {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("Beakon/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return parseUsageResponse(data, subscriptionType: nil, rateLimitTier: nil)
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

    private func refreshToken(_ refreshToken: String) async -> OAuthCredentials.OAuthData? {
        guard let url = URL(string: "https://platform.claude.com/v1/oauth/token") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Beakon/1.0", forHTTPHeaderField: "User-Agent")

        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=9d1c250a-e61b-44d9-88ed-5944d1962f5e"
        request.httpBody = body.data(using: .utf8)

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
            subscriptionType: nil,
            rateLimitTier: nil
        )

        // Persist refreshed credentials
        persistCredentials(newCreds)

        return newCreds
    }

    private func persistCredentials(_ creds: OAuthCredentials.OAuthData) {
        cachedCredentials = creds

        // Build updated JSON
        let updatedJSON: [String: Any] = [
            "claudeAiOauth": [
                "accessToken": creds.accessToken,
                "refreshToken": creds.refreshToken,
                "expiresAt": creds.expiresAt,
                "subscriptionType": creds.subscriptionType as Any,
                "rateLimitTier": creds.rateLimitTier as Any
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: updatedJSON, options: .prettyPrinted) else { return }

        // Write to Claude's own file if it exists
        let filePath = claudeDir.appendingPathComponent(".credentials.json")
        if FileManager.default.fileExists(atPath: filePath.path) {
            try? data.write(to: filePath)
        }

        // Always write to Beakon's local cache
        try? data.write(to: beakonCachePath)
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
