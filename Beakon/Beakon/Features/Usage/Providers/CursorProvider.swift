//
//  CursorProvider.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import os

final class CursorProvider: UsageProvider {
    let id = "cursor"
    let name = "Cursor"
    let iconName = "cursorarrow.rays"

    private let logger = Logger(subsystem: "com.beakon", category: "Cursor")
    private let keychain = KeychainService()
    private var lastLimits: ProviderLimits?
    private var lastPlan: String?

    private var stateDBPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb").path
    }

    var isConfigured: Bool {
        loadAccessToken() != nil
    }

    func configure(with credentials: ProviderCredentials) {}

    func fetchUsage() async throws -> UsageSnapshot {
        guard let token = loadAccessToken() else {
            return UsageSnapshot(
                totalInputTokens: 0, totalOutputTokens: 0, totalCostUSD: 0,
                periodStart: Date(), periodEnd: Date(), modelBreakdown: [],
                authStatus: .notAuthenticated(hint: "Open Cursor to authenticate")
            )
        }

        let freshLimits = await fetchUsageLimits(token: token)
        let freshPlan = await fetchPlanInfo(token: token)

        if let freshLimits { lastLimits = freshLimits }
        if let freshPlan { lastPlan = freshPlan }

        return UsageSnapshot(
            totalInputTokens: 0, totalOutputTokens: 0, totalCostUSD: 0,
            periodStart: Date(), periodEnd: Date(), modelBreakdown: [],
            limits: freshLimits ?? lastLimits,
            planName: freshPlan ?? lastPlan
        )
    }

    // MARK: - Token from Cursor's SQLite DB

    private func loadAccessToken() -> String? {
        // Read from Cursor's state.vscdb
        guard FileManager.default.fileExists(atPath: stateDBPath) else { return nil }

        let result = shell("sqlite3 '\(stateDBPath)' \"SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken'\" 2>/dev/null")
        let token = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return nil }
        return token
    }

    private func loadRefreshToken() -> String? {
        guard FileManager.default.fileExists(atPath: stateDBPath) else { return nil }
        let result = shell("sqlite3 '\(stateDBPath)' \"SELECT value FROM ItemTable WHERE key = 'cursorAuth/refreshToken'\" 2>/dev/null")
        let token = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }

    private func loadMembershipType() -> String? {
        guard FileManager.default.fileExists(atPath: stateDBPath) else { return nil }
        let result = shell("sqlite3 '\(stateDBPath)' \"SELECT value FROM ItemTable WHERE key = 'cursorAuth/stripeMembershipType'\" 2>/dev/null")
        let val = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return val.isEmpty ? nil : val
    }

    // MARK: - Cursor Dashboard API (Connect RPC)

    private func fetchUsageLimits(token: String) async -> ProviderLimits? {
        guard let url = URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue("Beakon/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = "{}".data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.warning("Cursor usage API failed")
            return nil
        }

        var items: [ProviderLimits.LimitItem] = []
        let billingEnd = json["billingCycleEnd"] as? String
        let resetDetail = formatBillingReset(billingEnd)

        if let planUsage = json["planUsage"] as? [String: Any] {
            // Total usage (request-based, matches Cursor UI)
            if let totalPercent = planUsage["totalPercentUsed"] as? Double {
                let displayMsg = json["displayMessage"] as? String ?? resetDetail
                items.append(.init(title: "Total Usage", percent: min(100, Int(totalPercent.rounded())), detail: displayMsg))
            }

            // Credits: remaining / limit (spend-based)
            if let remaining = planUsage["remaining"] as? Double,
               let limit = planUsage["limit"] as? Double, limit > 0 {
                let detail = String(format: "$%.0f left / $%.0f", remaining / 100, limit / 100)
                let usedPercent = Int(((limit - remaining) / limit) * 100)
                items.append(.init(title: "Credits", percent: usedPercent, detail: detail, style: .spending))
            }
        }

        // On-demand spend limit
        if let spendLimit = json["spendLimitUsage"] as? [String: Any] {
            if let used = spendLimit["totalSpend"] as? Double,
               let limit = spendLimit["individualLimit"] as? Double, limit > 0 {
                let percent = min(100, Int((used / limit) * 100))
                let detail = String(format: "$%.2f / $%.0f", used / 100, limit / 100)
                items.append(.init(title: "On-demand", percent: percent, detail: detail, style: .spending))
            }
        }

        guard !items.isEmpty else { return nil }
        return ProviderLimits(items: items)
    }

    private func fetchPlanInfo(token: String) async -> String? {
        guard let url = URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetPlanInfo") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue("Beakon/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = "{}".data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let planInfo = json["planInfo"] as? [String: Any],
              let name = planInfo["planName"] as? String else {
            // Fallback to locally stored membership type
            return loadMembershipType()?.capitalized
        }

        return name.capitalized
    }

    private func formatBillingReset(_ billingEnd: String?) -> String {
        guard let endStr = billingEnd,
              let endMs = Double(endStr) else { return "" }
        let endDate = Date(timeIntervalSince1970: endMs / 1000)
        let remaining = endDate.timeIntervalSinceNow
        guard remaining > 0 else { return "Resetting..." }

        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        if days > 0 {
            return "Resets in \(days)d \(hours)h"
        }
        return "Resets in \(hours)h"
    }

    // MARK: - Shell helper

    private func shell(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
