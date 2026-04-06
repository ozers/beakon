//
//  ProviderDashboardView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI
import Charts

struct ProviderDashboardView: View {
    @Environment(UsageService.self) private var usageService
    @Environment(UsagePollingService.self) private var pollingService
    let providerId: String

    @State private var snapshot: UsageSnapshot?
    @State private var isLoading = false
    @State private var error: String?
    @State private var providerName: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                if let snapshot {
                    // Limits from OAuth API
                    if let limits = snapshot.limits {
                        limitsCard(limits, planName: snapshot.planName)
                    }

                    todayCard(snapshot)

                    if !snapshot.dailyMessageCounts.isEmpty {
                        chartCard(snapshot)
                    }

                    if !snapshot.projectBreakdown.isEmpty {
                        breakdownCard(snapshot.projectBreakdown, title: providerId == "cursor" ? "Models" : "Projects")
                    }
                } else if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading usage data...").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                }
            }
            .padding(24)
        }
        .onAppear { loadCached() }
    }

    // MARK: - Fetch

    private func loadCached() {
        if let provider = usageService.allProviders.first(where: { $0.id == providerId }) {
            providerName = provider.name
        }
        snapshot = usageService.cachedSnapshot(for: providerId)
    }

    private func fetchData() async {
        guard let provider = usageService.allProviders.first(where: { $0.id == providerId }),
              provider.isConfigured else { return }
        providerName = provider.name
        isLoading = true
        error = nil
        let result = await Task.detached { try await provider.fetchUsage() }.result
        switch result {
        case .success(let snap): snapshot = snap
        case .failure(let err): error = err.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            ProviderIconView(providerId: providerId, size: 22)
            Text(providerName.isEmpty ? providerId : providerName)
                .font(.title2.bold())
            Spacer()

            if isLoading {
                ProgressView().controlSize(.small)
            }

            Button {
                Task { await fetchData() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
        }
    }

    // MARK: - Limits (generic from snapshot)

    private func limitsCard(_ limits: ProviderLimits, planName: String?) -> some View {
        GroupBox(planName.map { "Plan Usage — \($0)" } ?? "Plan Usage") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(limits.items.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Divider() }
                    limitRow(title: item.title, percent: item.percent, detail: item.detail)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func limitRow(title: String, percent: Int, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.bold())
                Spacer()
                Text("\(percent)%")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(limitColor(percent))
            }
            ProgressView(value: Double(min(percent, 100)) / 100.0)
                .tint(limitColor(percent))
            if !detail.isEmpty {
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func limitColor(_ percent: Int) -> Color {
        percent >= 80 ? .red : percent >= 50 ? .orange : .blue
    }

    // MARK: - Today

    private func todayCard(_ snapshot: UsageSnapshot) -> some View {
        GroupBox("Today") {
            HStack(spacing: 24) {
                statBlock(
                    value: "\(snapshot.messageCount)",
                    label: providerId == "cursor" ? "Generations" : "Messages",
                    icon: providerId == "cursor" ? "wand.and.stars" : "text.bubble"
                )
                if snapshot.sessionCount > 0 {
                    Divider().frame(height: 40)
                    statBlock(
                        value: "\(snapshot.sessionCount)",
                        label: providerId == "cursor" ? "Composer" : "Sessions",
                        icon: providerId == "cursor" ? "paintbrush" : "rectangle.stack"
                    )
                }
                if snapshot.totalCostUSD > 0 {
                    Divider().frame(height: 40)
                    statBlock(value: String(format: "$%.2f", snapshot.totalCostUSD), label: "Cost", icon: "dollarsign.circle")
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private func statBlock(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3).foregroundStyle(.tint).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title3.monospacedDigit().bold())
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Chart

    private func chartCard(_ snapshot: UsageSnapshot) -> some View {
        GroupBox("Last 7 Days") {
            Chart(snapshot.dailyMessageCounts, id: \.date) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Count", day.count)
                )
                .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Color.accentColor : Color.blue.opacity(0.5))
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 160)
        }
    }

    // MARK: - Breakdown

    private func breakdownCard(_ items: [UsageSnapshot.ProjectUsage], title: String) -> some View {
        GroupBox(title) {
            VStack(spacing: 0) {
                let maxCount = items.first?.messageCount ?? 1
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Divider() }
                    HStack(spacing: 12) {
                        Image(systemName: "folder").foregroundStyle(.secondary).frame(width: 20)
                        Text(item.name).font(.subheadline).lineLimit(1).frame(minWidth: 100, alignment: .leading)
                        GeometryReader { geo in
                            let fraction = CGFloat(item.messageCount) / CGFloat(max(1, maxCount))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor.opacity(0.6))
                                .frame(width: geo.size.width * fraction)
                        }
                        .frame(height: 8)
                        Text("\(item.messageCount)")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
}
