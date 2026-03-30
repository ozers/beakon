//
//  OverviewDashboardView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI
import Charts

struct OverviewDashboardView: View {
    @Environment(UsageService.self) private var usageService
    @Environment(UsagePollingService.self) private var pollingService
    @State private var snapshots: [String: UsageSnapshot] = [:]
    @State private var isLoading = false
    @State private var providerList: [(id: String, name: String)] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image("MenuBarIcon")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Overview")
                        .font(.title2.bold())
                    Spacer()

                    if isLoading {
                        ProgressView().controlSize(.small)
                    }

                    Button {
                        Task { await fetchAll() }
                    } label: {
                        Label("Refresh All", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(providerList, id: \.id) { provider in
                        providerCard(id: provider.id, name: provider.name)
                    }
                }

                if !chartEntries.isEmpty {
                    GroupBox("Combined Activity — Last 7 Days") {
                        Chart {
                            ForEach(chartEntries, id: \.id) { entry in
                                BarMark(
                                    x: .value("Day", entry.date, unit: .day),
                                    y: .value("Count", entry.count)
                                )
                                .foregroundStyle(by: .value("Provider", entry.provider))
                                .cornerRadius(3)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .frame(height: 180)
                    }
                }
            }
            .padding(24)
        }
        .task { await fetchAll() }
    }

    private func providerCard(id: String, name: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ProviderIconView(providerId: id, size: 16)
                    Text(name).font(.headline)
                    Spacer()
                    Circle().fill(.green).frame(width: 8, height: 8)
                }

                if let snap = snapshots[id] {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(snap.messageCount)")
                                .font(.title.monospacedDigit().bold())
                            Text(id == "cursor" ? "Generations" : "Messages")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if snap.sessionCount > 0 {
                            VStack(alignment: .trailing) {
                                Text("\(snap.sessionCount)")
                                    .font(.title.monospacedDigit().bold())
                                Text("Sessions")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("Loading...")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func fetchAll() async {
        // Cache provider list once at start — avoid reading @Observable in body
        let configured = usageService.allProviders.filter { $0.isConfigured }
        providerList = configured.map { (id: $0.id, name: $0.name) }

        isLoading = true
        for provider in configured {
            let snap = await Task.detached { try? await provider.fetchUsage() }.value
            if let snap { snapshots[provider.id] = snap }
        }
        isLoading = false
    }

    // MARK: - Chart

    private struct ChartEntry: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
        let provider: String
    }

    private var chartEntries: [ChartEntry] {
        var entries: [ChartEntry] = []
        for (id, snap) in snapshots {
            let name = providerList.first { $0.id == id }?.name ?? id
            for day in snap.dailyMessageCounts {
                entries.append(ChartEntry(date: day.date, count: day.count, provider: name))
            }
        }
        return entries
    }
}
