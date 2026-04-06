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
                headerSection

                if providerList.isEmpty && !isLoading {
                    emptyState
                } else {
                    ForEach(providerList, id: \.id) { provider in
                        providerCard(id: provider.id, name: provider.name)
                    }
                }

                if !chartEntries.isEmpty {
                    chartSection
                }
            }
            .padding(24)
        }
        .onAppear { loadCached() }
        .task { await fetchAll() }
    }

    // MARK: - Header

    private var headerSection: some View {
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
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No providers configured")
                .font(.headline).foregroundStyle(.secondary)
            Text("Set up Claude Code, Cursor, or Codex to start tracking usage.")
                .font(.subheadline).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - Provider Card

    private func providerCard(id: String, name: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack {
                    ProviderIconView(providerId: id, size: 16)
                    Text(name).font(.headline)
                    Spacer()
                    if let snap = snapshots[id], let plan = snap.planName {
                        Text(plan)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    }
                    statusDot(for: id)
                }

                if let snap = snapshots[id] {
                    if let limits = snap.limits, !limits.items.isEmpty {
                        // Show usage limit bars
                        ForEach(Array(limits.items.enumerated()), id: \.offset) { _, item in
                            limitRow(item: item)
                        }
                    } else {
                        Text("No usage data")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else if isLoading {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text("Loading...").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Could not load data")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func limitRow(item: ProviderLimits.LimitItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(item.title).font(.caption)
                Spacer()
                Text("\(item.percent)%")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(limitColor(item.percent))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(.quaternary)
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(limitColor(item.percent))
                        .frame(width: geo.size.width * Double(min(item.percent, 100)) / 100.0, height: 5)
                }
            }
            .frame(height: 5)
            if !item.detail.isEmpty {
                Text(item.detail)
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func statusDot(for id: String) -> some View {
        Circle()
            .fill(snapshots[id] != nil ? Color.green : Color.gray.opacity(0.5))
            .frame(width: 8, height: 8)
    }

    private func limitColor(_ percent: Int) -> Color {
        percent >= 80 ? .red : percent >= 50 ? .orange : .blue
    }

    // MARK: - Chart

    private var chartSection: some View {
        GroupBox("Activity — Last 7 Days") {
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

    // MARK: - Data

    private func loadCached() {
        let configured = usageService.allProviders.filter { $0.isConfigured }
        providerList = configured.map { (id: $0.id, name: $0.name) }
        for provider in configured {
            if let snap = usageService.cachedSnapshot(for: provider.id) {
                snapshots[provider.id] = snap
            }
        }
    }

    private func fetchAll() async {
        let configured = usageService.allProviders.filter { $0.isConfigured }
        providerList = configured.map { (id: $0.id, name: $0.name) }

        isLoading = true
        for provider in configured {
            if let snap = await usageService.fetchProvider(provider.id) {
                snapshots[provider.id] = snap
            }
        }
        isLoading = false
    }

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
