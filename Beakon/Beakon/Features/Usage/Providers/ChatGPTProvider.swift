//
//  ChatGPTProvider.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import os

final class ChatGPTProvider: UsageProvider {
    let id = "chatgpt"
    let name = "ChatGPT"
    let iconName = "bubble.left.and.bubble.right"

    private let logger = Logger(subsystem: "com.beakon", category: "ChatGPT")

    private var conversationsDir: URL? {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.openai.chat")
        guard FileManager.default.fileExists(atPath: base.path) else { return nil }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: base.path)) ?? []
        if let dir = contents.first(where: { $0.hasPrefix("conversations-v3-") }) {
            return base.appendingPathComponent(dir)
        }
        return nil
    }

    var isConfigured: Bool {
        // TODO: Enable when ChatGPT OAuth/billing API is implemented
        false
    }

    func configure(with credentials: ProviderCredentials) {}

    func fetchUsage() async throws -> UsageSnapshot {
        guard let dir = conversationsDir else { throw ProviderError.notConfigured }

        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
        let dataFiles = files.filter { $0.hasSuffix(".data") }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart

        var todayCount = 0
        var dailyMap: [String: Int] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for file in dataFiles {
            let filePath = dir.appendingPathComponent(file).path
            guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                  let modDate = attrs[.modificationDate] as? Date else { continue }
            if modDate >= sevenDaysAgo {
                dailyMap[dateFormatter.string(from: modDate), default: 0] += 1
            }
            if modDate >= todayStart { todayCount += 1 }
        }

        var dailyCounts: [DailyCount] = []
        for i in (0..<7).reversed() {
            let day = calendar.date(byAdding: .day, value: -i, to: todayStart) ?? todayStart
            dailyCounts.append(DailyCount(date: day, count: dailyMap[dateFormatter.string(from: day)] ?? 0))
        }

        return UsageSnapshot(
            totalInputTokens: todayCount,
            totalOutputTokens: 0,
            totalCostUSD: 0,
            periodStart: todayStart,
            periodEnd: Date(),
            modelBreakdown: [],
            dailyMessageCounts: dailyCounts,
            projectBreakdown: [
                UsageSnapshot.ProjectUsage(name: "Total conversations", messageCount: dataFiles.count)
            ]
        )
    }
}
