//
//  MenuBarView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    // Direct references — NOT read via @Environment to avoid MenuBarExtra observation cycles
    let usageService: UsageService
    let pollingService: UsagePollingService

    @State private var selectedProvider: String = UserDefaults.standard.string(forKey: "defaultProvider") ?? "claude-code"
    @State private var snapshot: UsageSnapshot?
    @State private var isLoading = false
    @State private var providers: [(id: String, name: String)] = []
    @State private var lastUpdated: String = ""
    @State private var loadID = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerView
            contentView
            Divider()
            footerView
        }
        .padding()
        .frame(width: 300)
        .task(id: loadID) {
            guard loadID > 0 else { return }
            await doLoad()
        }
        .onAppear {
            providers = usageService.configuredProviders.map { (id: $0.id, name: $0.name) }
            // Default to first configured provider if saved one isn't available
            if !providers.contains(where: { $0.id == selectedProvider }),
               let first = providers.first {
                selectedProvider = first.id
                UserDefaults.standard.set(first.id, forKey: "defaultProvider")
            }
            loadID += 1
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Menu {
                ForEach(providers, id: \.id) { p in
                    Button {
                        selectedProvider = p.id
                        UserDefaults.standard.set(p.id, forKey: "defaultProvider")
                        loadID += 1
                    } label: {
                        if p.id == selectedProvider {
                            Label(p.name, systemImage: "checkmark")
                        } else {
                            Text(p.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    ProviderIconView(providerId: selectedProvider, size: 14)
                    Text(providers.first { $0.id == selectedProvider }?.name ?? "Select")
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                Button { loadID += 1 } label: {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if let snap = snapshot {
            limitsSection(snap)

            if !lastUpdated.isEmpty {
                HStack {
                    Spacer()
                    Text(lastUpdated).font(.caption2).foregroundStyle(.quaternary)
                }
            }
        } else if providers.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("No provider configured")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Install Claude Code or add an API key in Settings")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        } else if isLoading {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Loading...").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Load

    private func doLoad() async {
        guard let provider = usageService.allProviders.first(where: { $0.id == selectedProvider }),
              provider.isConfigured else { return }

        isLoading = true
        let result = await Task.detached { try? await provider.fetchUsage() }.value
        snapshot = result
        isLoading = false
        lastUpdated = "Updated \(MenuBarIconRenderer.relativeTime(from: Date()))"
    }

    // MARK: - Limits

    @ViewBuilder
    private func limitsSection(_ snap: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch snap.authStatus {
            case .authenticated:
                if let limits = snap.limits {
                    if let plan = snap.planName {
                        HStack {
                            Spacer()
                            Text(plan)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    ForEach(Array(limits.items.enumerated()), id: \.offset) { _, item in
                        limitBar(title: item.title, percent: item.percent, detail: item.detail)
                    }
                } else {
                    Text("No usage data available")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

            case .notAuthenticated(let hint):
                VStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.title2).foregroundStyle(.secondary)
                    Text(hint)
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            case .expired:
                Label("Session expired — relaunch the tool to re-authenticate",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func limitBar(title: String, percent: Int, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption.bold())
                Spacer()
                Text("\(percent)%")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(limitColor(percent))
            }
            ProgressView(value: Double(min(percent, 100)) / 100.0)
                .tint(limitColor(percent))
            if !detail.isEmpty {
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func limitColor(_ percent: Int) -> Color {
        percent >= 80 ? .red : percent >= 50 ? .orange : .blue
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 0) {
            footerBtn(icon: "macwindow", label: "Dashboard") { openWindow(id: "main") }
            footerBtn(icon: "gear", label: "Settings") { openWindow(id: "main") }
            Spacer()
            footerBtn(icon: "power", label: "Quit") { NSApplication.shared.terminate(nil) }
        }
    }

    private func footerBtn(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 9))
            }
            .frame(width: 56, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }
}
