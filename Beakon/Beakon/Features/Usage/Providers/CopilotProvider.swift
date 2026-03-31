//
//  CopilotProvider.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import os

final class CopilotProvider: UsageProvider {
    let id = "copilot"
    let name = "GitHub Copilot"
    let iconName = "airplane"

    private let logger = Logger(subsystem: "com.beakon", category: "Copilot")

    private var ideDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".copilot/ide")
    }

    var isConfigured: Bool {
        // TODO: Enable when Copilot OAuth/billing API is implemented
        false
    }

    func configure(with credentials: ProviderCredentials) {}

    func fetchUsage() async throws -> UsageSnapshot {
        guard isConfigured else { throw ProviderError.notConfigured }

        let sessions = parseSessions()
        let todayStart = Calendar.current.startOfDay(for: Date())
        let todaySessions = sessions.filter { $0.timestamp >= todayStart }

        var projectCounts: [String: Int] = [:]
        for session in todaySessions {
            for folder in session.workspaceFolders {
                let name = folder.split(separator: "/").last.map(String.init) ?? folder
                projectCounts[name, default: 0] += 1
            }
        }

        let projectBreakdown = projectCounts.sorted { $0.value > $1.value }
            .map { UsageSnapshot.ProjectUsage(name: $0.key, messageCount: $0.value) }

        let calendar = Calendar.current
        var dailyCounts: [DailyCount] = []
        for i in (0..<7).reversed() {
            let dayStart = calendar.date(byAdding: .day, value: -i, to: calendar.startOfDay(for: Date())) ?? Date()
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? Date()
            let count = sessions.filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }.count
            dailyCounts.append(DailyCount(date: dayStart, count: count))
        }

        return UsageSnapshot(
            totalInputTokens: todaySessions.count,
            totalOutputTokens: 0,
            totalCostUSD: 0,
            periodStart: todayStart,
            periodEnd: Date(),
            modelBreakdown: [],
            dailyMessageCounts: dailyCounts,
            projectBreakdown: projectBreakdown
        )
    }

    // MARK: - Parse lock files

    private struct CopilotSession {
        let pid: Int
        let ideName: String
        let timestamp: Date
        let workspaceFolders: [String]
    }

    private func parseSessions() -> [CopilotSession] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: ideDir.path) else { return [] }

        return files.compactMap { file -> CopilotSession? in
            guard file.hasSuffix(".lock") else { return nil }
            let path = ideDir.appendingPathComponent(file).path
            guard let data = fm.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            let pid = json["pid"] as? Int ?? 0
            let ideName = json["ideName"] as? String ?? "Unknown"
            let tsMs = json["timestamp"] as? Double ?? 0
            let folders = json["workspaceFolders"] as? [String] ?? []

            return CopilotSession(
                pid: pid, ideName: ideName,
                timestamp: Date(timeIntervalSince1970: tsMs / 1000),
                workspaceFolders: folders
            )
        }
    }
}
