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
    @State private var showSummary = false

    private var snapshot: UsageSnapshot? {
        usageService.cachedSnapshot(for: selectedProvider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showSettings {
                settingsPage
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            } else if showSummary {
                summaryPage
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            } else {
                headerView
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                contentView
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
            Divider()
            footerView
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .frame(width: 280)
        .onAppear {
            providers = usageService.configuredProviders.map { (id: $0.id, name: $0.name) }
            if !providers.contains(where: { $0.id == selectedProvider }),
               let first = providers.first {
                selectedProvider = first.id
                UserDefaults.standard.set(first.id, forKey: "defaultProvider")
            }
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

            if !updatedAgoText.isEmpty {
                HStack {
                    Spacer()
                    Text(updatedAgoText).font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        } else if providers.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("No provider configured")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Install Claude Code or add an API key in Settings")
                    .font(.caption).foregroundStyle(.secondary)
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
                    .font(.caption2).foregroundStyle(.secondary)
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
                    .onChange(of: pollingInterval) { _, v in
                                UserDefaults.standard.set(v, forKey: "pollingInterval")
                                pollingService.restartWithCurrentInterval()
                            }
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
                    .font(.caption2).foregroundStyle(.secondary)
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
                                .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
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
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text("\(percent)%")
                    .font(.caption.monospacedDigit().bold())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.primary.opacity(0.15))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(limitColor(percent))
                        .frame(width: geo.size.width * Double(min(percent, 100)) / 100.0, height: 5)
                }
            }
            .frame(height: 5)
            if !detail.isEmpty {
                Text(detail).font(.caption2).foregroundStyle(.primary.opacity(0.65))
            }
        }
    }

    private func limitColor(_ percent: Int) -> Color {
        percent >= 80 ? .red : percent >= 50 ? .orange : .accentColor
    }

    // MARK: - Summary Page

    private var summaryPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { showSummary = false } label: {
                    Image(systemName: "chevron.left").font(.caption.bold())
                }
                .buttonStyle(.borderless)
                Text("All Providers").font(.headline)
                Spacer()
            }

            if providers.isEmpty {
                Text("No providers configured")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(providers, id: \.id) { provider in
                    summaryProviderRow(id: provider.id, name: provider.name)
                    if provider.id != providers.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func summaryProviderRow(id: String, name: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ProviderIconView(providerId: id, size: 12)
                Text(name).font(.caption.bold())
                Spacer()
                if let snap = usageService.cachedSnapshot(for: id), let plan = snap.planName {
                    Text(plan)
                        .font(.system(size: 9).bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                }
            }

            if let snap = usageService.cachedSnapshot(for: id),
               let limits = snap.limits,
               let primary = limits.items.first(where: { $0.style == .bar }) {
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color.primary.opacity(0.15))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(limitColor(primary.percent))
                                .frame(width: geo.size.width * Double(min(primary.percent, 100)) / 100.0, height: 5)
                        }
                    }
                    .frame(height: 5)
                    Text("\(primary.percent)%")
                        .font(.caption2.monospacedDigit().bold())
                        .frame(width: 32, alignment: .trailing)
                }
                if !primary.detail.isEmpty {
                    Text(primary.detail)
                        .font(.caption2).foregroundStyle(.primary.opacity(0.65))
                }
            } else {
                Text("No data")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 0) {
            footerBtn(icon: "macwindow", label: "Dashboard") {
                NSApp.activate()
                openWindow(id: "main")
            }
            Spacer()
            footerBtn(icon: "list.bullet", label: "Summary") {
                showSummary.toggle()
                showSettings = false
            }
            Spacer()
            footerBtn(icon: "gear", label: "Settings") {
                showSettings.toggle()
                showSummary = false
            }
            Spacer()
            footerBtn(icon: "power", label: "Quit") { NSApplication.shared.terminate(nil) }
        }
    }

    private func footerBtn(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 9))
            }
            .frame(width: 60, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }
}
