//
//  MenuBarIconRenderer.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI

struct MenuBarIconRenderer {
    static func costText(from snapshot: UsageSnapshot?) -> String {
        guard let snapshot else { return "" }
        return String(format: "$%.2f", snapshot.totalCostUSD)
    }

    static func statusColor(for snapshot: UsageSnapshot?) -> Color {
        guard let snapshot else { return .secondary }

        let warningThreshold = UserDefaults.standard.integer(forKey: "warningThreshold")
        let criticalThreshold = UserDefaults.standard.integer(forKey: "criticalThreshold")
        let warning = warningThreshold > 0 ? warningThreshold : 75
        let critical = criticalThreshold > 0 ? criticalThreshold : 90

        // For now use a simple cost-based heuristic
        // This will be replaced with actual limit percentages when session tracking is added
        let dailyBudget = 10.0 // Default $10/day
        let percentage = (snapshot.totalCostUSD / dailyBudget) * 100

        if percentage >= Double(critical) {
            return .red
        } else if percentage >= Double(warning) {
            return .yellow
        }
        return .green
    }

    static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    static func relativeTime(from date: Date?) -> String {
        guard let date else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
