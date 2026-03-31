//
//  UsageService.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import os

@Observable
@MainActor
final class UsageService {
    private(set) var currentSnapshot: UsageSnapshot?
    private(set) var isLoading = false
    private(set) var lastError: Error?
    private(set) var providerSnapshots: [String: UsageSnapshot] = [:]

    var onSnapshotUpdate: ((UsageSnapshot) -> Void)?

    private var providers: [any UsageProvider] = []
    private let logger = Logger(subsystem: "com.beakon", category: "UsageService")

    init(providers: [any UsageProvider]? = nil) {
        self.providers = providers ?? [ClaudeCodeProvider(), CursorProvider(), CodexProvider(), CopilotProvider(), ChatGPTProvider(), ClaudeAPIProvider()]
    }

    var allProviders: [any UsageProvider] {
        providers
    }

    var configuredProviders: [any UsageProvider] {
        providers.filter { $0.isConfigured }
    }

    var hasConfiguredProviders: Bool {
        !configuredProviders.isEmpty
    }

    func refreshAll() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let configured = configuredProviders
        guard !configured.isEmpty else {
            logger.info("No configured providers to refresh")
            return
        }

        // For now, use the first configured provider's snapshot
        // Multi-provider aggregation will come later
        do {
            let snapshot = try await configured[0].fetchUsage()
            currentSnapshot = snapshot
            onSnapshotUpdate?(snapshot)
            logger.info("Usage refreshed: \(snapshot.totalTokens) tokens, $\(String(format: "%.2f", snapshot.totalCostUSD))")
        } catch {
            lastError = error
            logger.error("Usage refresh failed: \(error.localizedDescription)")
        }
    }

    func fetchProvider(_ id: String) async -> UsageSnapshot? {
        guard let provider = providers.first(where: { $0.id == id }),
              provider.isConfigured else { return providerSnapshots[id] }
        let snap = try? await provider.fetchUsage()
        if let snap { providerSnapshots[id] = snap }
        return snap ?? providerSnapshots[id]
    }

    func cachedSnapshot(for id: String) -> UsageSnapshot? {
        providerSnapshots[id]
    }

    func addProvider(_ provider: any UsageProvider) {
        providers.append(provider)
    }

    func updateProvider<T: UsageProvider>(_ type: T.Type, credentials: ProviderCredentials) {
        guard let provider = providers.first(where: { $0 is T }) else { return }
        provider.configure(with: credentials)
    }
}
