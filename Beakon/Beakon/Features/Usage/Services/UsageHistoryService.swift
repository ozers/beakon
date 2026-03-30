//
//  UsageHistoryService.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import SwiftData
import os

@Model
final class UsageHistoryEntry {
    var date: Date
    var totalCost: Double
    var totalInputTokens: Int
    var totalOutputTokens: Int
    var model: String

    init(date: Date, totalCost: Double, totalInputTokens: Int, totalOutputTokens: Int, model: String = "all") {
        self.date = date
        self.totalCost = totalCost
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens
        self.model = model
    }
}

@MainActor
final class UsageHistoryService {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.beakon", category: "UsageHistory")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func record(snapshot: UsageSnapshot) {
        let today = Calendar.current.startOfDay(for: Date())

        // Check if we already have an entry for today — update it instead of duplicating
        let predicate = #Predicate<UsageHistoryEntry> { entry in
            entry.date >= today && entry.model == "all"
        }
        let descriptor = FetchDescriptor(predicate: predicate)

        do {
            let existing = try modelContext.fetch(descriptor)
            if let entry = existing.first {
                entry.totalCost = snapshot.totalCostUSD
                entry.totalInputTokens = snapshot.totalInputTokens
                entry.totalOutputTokens = snapshot.totalOutputTokens
            } else {
                let entry = UsageHistoryEntry(
                    date: today,
                    totalCost: snapshot.totalCostUSD,
                    totalInputTokens: snapshot.totalInputTokens,
                    totalOutputTokens: snapshot.totalOutputTokens
                )
                modelContext.insert(entry)
            }
            try modelContext.save()
        } catch {
            logger.error("Failed to record history: \(error.localizedDescription)")
        }
    }

    func fetchLast(days: Int) -> [UsageHistoryEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = #Predicate<UsageHistoryEntry> { entry in
            entry.date >= cutoff && entry.model == "all"
        }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch history: \(error.localizedDescription)")
            return []
        }
    }
}
