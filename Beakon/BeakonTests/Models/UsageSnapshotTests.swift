//
//  UsageSnapshotTests.swift
//  BeakonTests
//
//  Created by Ozer on 30.03.2026.
//

import Testing
import Foundation
@testable import Beakon

struct UsageSnapshotTests {

    @Test func totalTokensComputed() {
        let snapshot = UsageSnapshot(
            totalInputTokens: 10000,
            totalOutputTokens: 5000,
            totalCostUSD: 1.50,
            periodStart: Date(),
            periodEnd: Date(),
            modelBreakdown: []
        )

        #expect(snapshot.totalTokens == 15000)
    }

    @Test func modelBreakdown() {
        let breakdown = [
            UsageSnapshot.ModelUsage(model: "claude-sonnet-4", inputTokens: 8000, outputTokens: 3000, costUSD: 0.80),
            UsageSnapshot.ModelUsage(model: "claude-opus-4", inputTokens: 2000, outputTokens: 2000, costUSD: 0.70),
        ]

        let snapshot = UsageSnapshot(
            totalInputTokens: 10000,
            totalOutputTokens: 5000,
            totalCostUSD: 1.50,
            periodStart: Date(),
            periodEnd: Date(),
            modelBreakdown: breakdown
        )

        #expect(snapshot.modelBreakdown.count == 2)
        #expect(snapshot.modelBreakdown[0].model == "claude-sonnet-4")
        #expect(snapshot.modelBreakdown[1].costUSD == 0.70)
    }
}
