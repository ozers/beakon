//
//  CostChartView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI
import Charts

struct CostChartView: View {
    let entries: [UsageHistoryEntry]

    private var last7Days: [UsageHistoryEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return entries.filter { $0.date >= cutoff }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("7-Day Cost")
                .font(.caption)
                .foregroundStyle(.secondary)

            if last7Days.isEmpty {
                Text("No data yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(last7Days, id: \.date) { entry in
                    let isToday = Calendar.current.isDateInToday(entry.date)
                    BarMark(
                        x: .value("Day", entry.date, unit: .day),
                        y: .value("Cost", entry.totalCost)
                    )
                    .foregroundStyle(isToday ? Color.accentColor : Color.blue.opacity(0.6))
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let cost = value.as(Double.self) {
                                Text("$\(cost, specifier: "%.0f")")
                            }
                        }
                    }
                }
                .frame(height: 80)
            }
        }
    }
}
