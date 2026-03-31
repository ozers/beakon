//
//  CodexProvider.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import os

final class CodexProvider: UsageProvider {
    let id = "codex"
    let name = "Codex"
    let iconName = "chevron.left.forwardslash.chevron.right"

    private let logger = Logger(subsystem: "com.beakon", category: "Codex")
    private let keychain = KeychainService()
    private var lastLimits: UsageLimitsResult?

    var isConfigured: Bool {
        loadAuth() != nil
    }

    func configure(with credentials: ProviderCredentials) {}

    func fetchUsage() async throws -> UsageSnapshot {
        guard let auth = loadAuth() else {
            return UsageSnapshot(
                totalInputTokens: 0, totalOutputTokens: 0, totalCostUSD: 0,
                periodStart: Date(), periodEnd: Date(), modelBreakdown: [],
                authStatus: .notAuthenticated(hint: "Run codex to authenticate")
            )
        }

        let freshLimits = await fetchUsageLimits(auth: auth)
        if let freshLimits { lastLimits = freshLimits }
        let limits = freshLimits ?? lastLimits

        return UsageSnapshot(
            totalInputTokens: 0, totalOutputTokens: 0, totalCostUSD: 0,
            periodStart: Date(), periodEnd: Date(), modelBreakdown: [],
            limits: limits?.limits,
            planName: limits?.planName
        )
    }

    // MARK: - Auth file

    private struct CodexAuth {
        let accessToken: String
        let refreshToken: String?
        let accountId: String?
    }

    private func loadAuth() -> CodexAuth? {
        // Search paths in order
        let home = FileManager.default.homeDirectoryForCurrentUser
        var searchPaths: [String] = []
        if let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"] {
            searchPaths.append(URL(fileURLWithPath: codexHome).appendingPathComponent("auth.json").path)
        }
        searchPaths.append(home.appendingPathComponent(".config/codex/auth.json").path)
        searchPaths.append(home.appendingPathComponent(".codex/auth.json").path)

        for path in searchPaths {
            if let data = FileManager.default.contents(atPath: path),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tokens = json["tokens"] as? [String: Any],
               let accessToken = tokens["access_token"] as? String {
                return CodexAuth(
                    accessToken: accessToken,
                    refreshToken: tokens["refresh_token"] as? String,
                    accountId: tokens["account_id"] as? String
                )
            }
        }

        // Fallback: macOS Keychain
        if let json = try? keychain.loadExternal(service: "Codex Auth"),
           let data = json.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tokens = parsed["tokens"] as? [String: Any],
           let accessToken = tokens["access_token"] as? String {
            return CodexAuth(
                accessToken: accessToken,
                refreshToken: tokens["refresh_token"] as? String,
                accountId: tokens["account_id"] as? String
            )
        }

        return nil
    }

    // MARK: - Usage API

    private struct UsageLimitsResult {
        let limits: ProviderLimits
        let planName: String?
    }

    private func fetchUsageLimits(auth: CodexAuth) async -> UsageLimitsResult? {
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountId = auth.accountId {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Try token refresh on failure
            if let refreshed = await refreshToken(auth) {
                return await fetchWithToken(refreshed)
            }
            logger.warning("Codex usage API failed")
            return nil
        }

        return parseUsageResponse(json)
    }

    private func fetchWithToken(_ auth: CodexAuth) async -> UsageLimitsResult? {
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountId = auth.accountId {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        return parseUsageResponse(json)
    }

    private func parseUsageResponse(_ json: [String: Any]) -> UsageLimitsResult? {
        var items: [ProviderLimits.LimitItem] = []

        // Session (5-hour primary window)
        if let rateLimit = json["rate_limit"] as? [String: Any],
           let primary = rateLimit["primary_window"] as? [String: Any],
           let usedPercent = primary["used_percent"] as? Double {
            let resetSeconds = primary["reset_after_seconds"] as? Double ?? 0
            let resetDetail = formatSeconds(resetSeconds)
            items.append(.init(title: "Session", percent: Int(usedPercent * 100), detail: resetDetail))
        }

        // Weekly (7-day secondary window)
        if let rateLimit = json["rate_limit"] as? [String: Any],
           let secondary = rateLimit["secondary_window"] as? [String: Any],
           let usedPercent = secondary["used_percent"] as? Double {
            let resetSeconds = secondary["reset_after_seconds"] as? Double ?? 0
            let resetDetail = formatSeconds(resetSeconds)
            items.append(.init(title: "Weekly", percent: Int(usedPercent * 100), detail: resetDetail))
        }

        // Credits balance
        if let credits = json["credits"] as? [String: Any],
           let balance = credits["balance"] as? Double, balance > 0 {
            items.append(.init(title: "Credits", percent: 0,
                              detail: String(format: "$%.2f remaining", balance), style: .spending))
        }

        let planType = json["plan_type"] as? String

        guard !items.isEmpty else { return nil }
        return UsageLimitsResult(
            limits: ProviderLimits(items: items),
            planName: planType?.capitalized
        )
    }

    private func formatSeconds(_ seconds: Double) -> String {
        guard seconds > 0 else { return "" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours >= 24 {
            return "Resets in \(hours / 24)d \(hours % 24)h"
        } else if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        }
        return "Resets in \(minutes)m"
    }

    // MARK: - Token refresh

    private func refreshToken(_ auth: CodexAuth) async -> CodexAuth? {
        guard let refreshToken = auth.refreshToken,
              let url = URL(string: "https://auth.openai.com/oauth/token") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=app_EMoamEEZ73f0CkXaXp7hrann"
        request.httpBody = body.data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String else {
            logger.warning("Codex token refresh failed")
            return nil
        }

        let newRefreshToken = json["refresh_token"] as? String ?? refreshToken

        // Persist to auth.json if it exists
        persistAuth(accessToken: newAccessToken, refreshToken: newRefreshToken)

        return CodexAuth(accessToken: newAccessToken, refreshToken: newRefreshToken, accountId: auth.accountId)
    }

    private func persistAuth(accessToken: String, refreshToken: String) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let paths = [
            home.appendingPathComponent(".config/codex/auth.json"),
            home.appendingPathComponent(".codex/auth.json")
        ]

        for path in paths {
            guard FileManager.default.fileExists(atPath: path.path),
                  let data = try? Data(contentsOf: path),
                  var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  var tokens = json["tokens"] as? [String: Any] else { continue }

            tokens["access_token"] = accessToken
            tokens["refresh_token"] = refreshToken
            json["tokens"] = tokens
            json["last_refresh"] = ISO8601DateFormatter().string(from: Date())

            if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
                try? updated.write(to: path)
            }
            break
        }
    }
}
