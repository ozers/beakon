//
//  ModelBreakdownView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI

struct ModelBreakdownView: View {
    let breakdown: [UsageSnapshot.ModelUsage]

    private var sorted: [UsageSnapshot.ModelUsage] {
        breakdown.sorted { ($0.inputTokens + $0.outputTokens) > ($1.inputTokens + $1.outputTokens) }
    }

    private var maxTokens: Int {
        sorted.first.map { $0.inputTokens + $0.outputTokens } ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Model Breakdown")
                .font(.caption)
                .foregroundStyle(.secondary)

            if sorted.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(sorted, id: \.model) { model in
                    let total = model.inputTokens + model.outputTokens
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(shortName(model.model))
                                .font(.caption.bold())
                            Spacer()
                            Text(MenuBarIconRenderer.formatTokens(total))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        GeometryReader { geo in
                            let fraction = maxTokens > 0 ? CGFloat(total) / CGFloat(maxTokens) : 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorFor(model.model))
                                .frame(width: geo.size.width * fraction)
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
    }

    private func shortName(_ name: String) -> String {
        if name.contains("opus") { return "Opus" }
        if name.contains("sonnet") { return "Sonnet" }
        if name.contains("haiku") { return "Haiku" }
        return name
    }

    private func colorFor(_ name: String) -> Color {
        if name.contains("opus") { return .purple }
        if name.contains("sonnet") { return .blue }
        if name.contains("haiku") { return .green }
        return .orange
    }
}
