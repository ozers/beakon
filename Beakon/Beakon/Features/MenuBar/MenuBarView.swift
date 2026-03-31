//
//  MenuBarView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI
import ServiceManagement

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    let usageService: UsageService
    let pollingService: UsagePollingService

    @State private var selectedProvider: String = UserDefaults.standard.string(forKey: "defaultProvider") ?? "claude-code"
    @State private var isLoading = false
    @State private var providers: [(id: String, name: String)] = []
    @State private var showSettings = false

    private var snapshot: UsageSnapshot? {
        usageService.cachedSnapshot(for: selectedProvider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showSettings {
                settingsPage
            } else {
                headerView
                contentView
            }
            Divider()
            footerView
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            providers = usageService.configuredProviders.map { (id: $0.id, name: $0.name) }
            if !providers.contains(where: { $0.id == selectedProvider }),
               let first = providers.first {
                selectedProvider = first.id
                UserDefaults.standard.set(first.id, forKey: "defaultProvider")
            }
            if snapshot == nil && !Self.initialLoadDone {
                Self.initialLoadDone = true
                Task { await doLoad() }
            }
        }
    }

    private static var initialLoadDone = false

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Menu {
                ForEach(providers, id: \.id) { p in
                    Button {
                        selectedProvider = p.id
                        UserDefaults.standard.set(p.id, forKey: "defaultProvider")
                        if usageService.cachedSnapshot(for: p.id) == nil {
                            Task { await doLoad() }
                        }
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
                Button { Task { await doLoad() } } label: {
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

            HStack {
                Spacer()
                Text(updatedAgoText).font(.caption2).foregroundStyle(.quaternary)
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
        } else {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.title2).foregroundStyle(.secondary)
                Text("Could not fetch usage data")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Rate limited — will retry automatically")
                    .font(.caption2).foregroundStyle(.tertiary)
                Button("Retry") { Task { await doLoad() } }
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Settings Page (inline)

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var pollingInterval = UserDefaults.standard.integer(forKey: "pollingInterval") == 0 ? 600 : UserDefaults.standard.integer(forKey: "pollingInterval")
    @State private var warningThreshold = UserDefaults.standard.integer(forKey: "warningThreshold") == 0 ? 75 : UserDefaults.standard.integer(forKey: "warningThreshold")
    @State private var criticalThreshold = UserDefaults.standard.integer(forKey: "criticalThreshold") == 0 ? 90 : UserDefaults.standard.integer(forKey: "criticalThreshold")

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { showSettings = false } label: {
                    Image(systemName: "chevron.left").font(.caption.bold())
                }
                .buttonStyle(.borderless)
                Text("Settings").font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Refresh") {
                    Picker("", selection: $pollingInterval) {
                        Text("1 min").tag(60)
                        Text("5 min").tag(300)
                        Text("10 min").tag(600)
                        Text("30 min").tag(1800)
                    }
                    .frame(width: 100)
                    .onChange(of: pollingInterval) { _, v in UserDefaults.standard.set(v, forKey: "pollingInterval") }
                }
                .font(.caption)

                Divider()

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .font(.caption)
                    .onChange(of: launchAtLogin) { _, v in
                        do { try v ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
                        catch { launchAtLogin = !v }
                    }

                Divider()

                LabeledContent("Warn at") {
                    Stepper("\(warningThreshold)%", value: $warningThreshold, in: 50...95, step: 5)
                        .onChange(of: warningThreshold) { _, v in UserDefaults.standard.set(v, forKey: "warningThreshold") }
                }
                .font(.caption)

                LabeledContent("Critical at") {
                    Stepper("\(criticalThreshold)%", value: $criticalThreshold, in: 60...99, step: 5)
                        .onChange(of: criticalThreshold) { _, v in UserDefaults.standard.set(v, forKey: "criticalThreshold") }
                }
                .font(.caption)
            }
            .padding(.vertical, 4)

            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text("Beakon v\(AppConstants.appVersion)")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Load

    private var updatedAgoText: String {
        let ts = UserDefaults.standard.double(forKey: "lastMenuBarFetch")
        guard ts > 0 else { return "" }
        return "Updated \(MenuBarIconRenderer.relativeTime(from: Date(timeIntervalSince1970: ts)))"
    }

    private func doLoad() async {
        isLoading = true
        let id = selectedProvider
        let _ = await Task.detached { [usageService] in
            await usageService.fetchProvider(id)
        }.value
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastMenuBarFetch")
        isLoading = false
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
            footerBtn(icon: "macwindow", label: "Dashboard") {
                NSApp.activate()
                openWindow(id: "main")
            }
            footerBtn(icon: "gear", label: "Settings") {
                showSettings.toggle()
            }
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
