//
//  ClaudeAPIProvider.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation

final class ClaudeAPIProvider: UsageProvider {
    let id = "claude-api"
    let name = "Claude API"
    let iconName = "brain.head.profile"

    private let keychain: KeychainService
    private let keychainKey = "anthropic-admin-api-key"
    private var api: AnthropicAPI?

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
        if let key = try? keychain.load(key: keychainKey) {
            self.api = AnthropicAPI(apiKey: key)
        }
    }

    var isConfigured: Bool {
        api != nil
    }

    func configure(with credentials: ProviderCredentials) {
        guard case .apiKey(let key) = credentials else { return }
        try? keychain.save(key: keychainKey, value: key)
        api = AnthropicAPI(apiKey: key)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let api else {
            throw ProviderError.notConfigured
        }

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now

        let formatter = ISO8601DateFormatter()
        let startingAt = formatter.string(from: yesterday)
        let endingAt = formatter.string(from: now)

        async let usageTask = api.fetchUsageReport(
            startingAt: startingAt,
            endingAt: endingAt,
            bucketWidth: "1h",
            groupBy: "model"
        )
        async let costTask = api.fetchCostReport(
            startingAt: startingAt,
            endingAt: endingAt
        )

        let (usageReport, costReport) = try await (usageTask, costTask)

        return buildSnapshot(
            usage: usageReport,
            cost: costReport,
            periodStart: yesterday,
            periodEnd: now
        )
    }

    private func buildSnapshot(
        usage: UsageReport,
        cost: CostReport,
        periodStart: Date,
        periodEnd: Date
    ) -> UsageSnapshot {
        var totalInput = 0
        var totalOutput = 0
        var modelMap: [String: (input: Int, output: Int)] = [:]

        for bucket in usage.data {
            totalInput += bucket.inputTokens
            totalOutput += bucket.outputTokens

            let model = bucket.model ?? "unknown"
            let existing = modelMap[model, default: (0, 0)]
            modelMap[model] = (existing.input + bucket.inputTokens, existing.output + bucket.outputTokens)
        }

        let totalCost = cost.data.reduce(0.0) { $0 + $1.amountUSD }

        let breakdown = modelMap.map { model, tokens in
            UsageSnapshot.ModelUsage(
                model: model,
                inputTokens: tokens.input,
                outputTokens: tokens.output,
                costUSD: 0
            )
        }

        return UsageSnapshot(
            totalInputTokens: totalInput,
            totalOutputTokens: totalOutput,
            totalCostUSD: totalCost,
            periodStart: periodStart,
            periodEnd: periodEnd,
            modelBreakdown: breakdown
        )
    }
}

enum ProviderError: Error, LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Provider is not configured — add your API key in Settings"
        }
    }
}
