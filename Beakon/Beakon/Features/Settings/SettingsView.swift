//
//  SettingsView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    // General
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var iCloudSync = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    @State private var warningThreshold = UserDefaults.standard.integer(forKey: "warningThreshold") == 0 ? 75 : UserDefaults.standard.integer(forKey: "warningThreshold")
    @State private var criticalThreshold = UserDefaults.standard.integer(forKey: "criticalThreshold") == 0 ? 90 : UserDefaults.standard.integer(forKey: "criticalThreshold")
    @State private var pollingInterval = UserDefaults.standard.integer(forKey: "pollingInterval") == 0 ? 300 : UserDefaults.standard.integer(forKey: "pollingInterval")

    // Claude API (org admin key — separate from OAuth)
    @State private var apiKey = ""
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isTesting = false
    @State private var statusMessage = ""
    @State private var showAPISection = false

    private let keychain = KeychainService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.largeTitle.bold())

                // MARK: - Claude API (org admin key)
                sectionHeader("Claude API", icon: "cloud")

                DisclosureGroup(isExpanded: $showAPISection) {
                    claudeAPIContent
                        .padding(.leading, 36)
                        .padding(.top, 8)
                } label: {
                    providerRowLabel(
                        icon: "cloud", name: "Organization Usage",
                        status: "Requires Admin API key for cost tracking",
                        isActive: connectionStatus == .connected,
                        hasError: connectionStatus == .error
                    )
                }

                Divider()

                // MARK: - General
                sectionHeader("General", icon: "gear")

                settingsCard {
                    LabeledContent("Refresh Interval") {
                        Picker("", selection: $pollingInterval) {
                            Text("1 min").tag(60)
                            Text("5 min").tag(300)
                            Text("10 min").tag(600)
                            Text("30 min").tag(1800)
                        }
                        .frame(width: 120)
                        .onChange(of: pollingInterval) { _, v in UserDefaults.standard.set(v, forKey: "pollingInterval") }
                    }

                    Divider()

                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, v in
                            do { try v ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
                            catch { launchAtLogin = !v }
                        }

                    Divider()

                    Toggle("iCloud Sync (Prompts)", isOn: $iCloudSync)
                        .onChange(of: iCloudSync) { _, v in UserDefaults.standard.set(v, forKey: "iCloudSyncEnabled") }
                    Text("Requires restart to take effect")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Divider()

                // MARK: - Notifications
                sectionHeader("Notifications", icon: "bell")

                settingsCard {
                    LabeledContent("Warning") {
                        Stepper("\(warningThreshold)%", value: $warningThreshold, in: 50...95, step: 5)
                            .onChange(of: warningThreshold) { _, v in UserDefaults.standard.set(v, forKey: "warningThreshold") }
                    }
                    Divider()
                    LabeledContent("Critical") {
                        Stepper("\(criticalThreshold)%", value: $criticalThreshold, in: 60...99, step: 5)
                            .onChange(of: criticalThreshold) { _, v in UserDefaults.standard.set(v, forKey: "criticalThreshold") }
                    }
                }

                // MARK: - About
                Divider()
                sectionHeader("About", icon: "info.circle")

                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Beakon")
                            .font(.title3.bold())
                        Text("v\(AppConstants.appVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Link("GitHub", destination: URL(string: AppConstants.githubURL)!)
                            .font(.caption)
                    }
                }
                .padding()
            }
            .padding(32)
        }
        .onAppear {
            loadExistingKey()
            showAPISection = connectionStatus != .unknown
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.title3.bold())
            .foregroundStyle(.primary)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func providerRowLabel(icon: String, name: String, status: String, isActive: Bool, hasError: Bool = false) -> some View {
        let dotColor: Color = hasError ? .red : (isActive ? .green : .gray.opacity(0.4))
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body.bold())
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(dotColor)
                .frame(width: 9, height: 9)
        }
    }

    // MARK: - Claude API

    @ViewBuilder
    private var claudeAPIContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            SecureField("sk-ant-admin01-...", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            Label("Requires an Admin key, not a regular API key", systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.orange)

            Label {
                Link("console.anthropic.com → Admin Keys", destination: URL(string: "https://console.anthropic.com/settings/organization/admin-keys")!)
                    .font(.caption)
            } icon: {
                Image(systemName: "arrow.up.right.square").font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Save") { saveAPIKey() }
                    .disabled(apiKey.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Test") { Task { await testConnection() } }
                    .disabled(apiKey.isEmpty && connectionStatus == .unknown)
                    .controlSize(.small)
                if connectionStatus != .unknown {
                    Button("Remove") { removeAPIKey() }
                        .controlSize(.small).foregroundStyle(.red)
                }
                if isTesting { ProgressView().controlSize(.small) }
            }

            if !statusMessage.isEmpty {
                Label(statusMessage, systemImage: connectionStatus == .error ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(connectionStatus == .error ? .red : .green)
            }
        }
    }

    // MARK: - API Key

    private func loadExistingKey() {
        if let key = try? keychain.load(key: "anthropic-admin-api-key") {
            apiKey = key
            connectionStatus = .configured
        }
    }

    private func removeAPIKey() {
        try? keychain.delete(key: "anthropic-admin-api-key")
        apiKey = ""; connectionStatus = .unknown; statusMessage = ""; showAPISection = false
    }

    private func saveAPIKey() {
        do {
            try keychain.save(key: "anthropic-admin-api-key", value: apiKey)
            connectionStatus = .configured; statusMessage = "Key saved"
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"; connectionStatus = .error
        }
    }

    private func testConnection() async {
        isTesting = true; defer { isTesting = false }
        if connectionStatus != .configured { saveAPIKey() }
        let api = AnthropicAPI(apiKey: apiKey)
        let f = ISO8601DateFormatter()
        let now = Date()
        let ago = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
        do {
            let _ = try await api.fetchUsageReport(startingAt: f.string(from: ago), endingAt: f.string(from: now), bucketWidth: "1h")
            connectionStatus = .connected; statusMessage = "Connected"
        } catch let e as APIError {
            connectionStatus = .error; statusMessage = e.localizedDescription
        } catch {
            connectionStatus = .error; statusMessage = error.localizedDescription
        }
    }
}

private enum ConnectionStatus {
    case unknown, configured, connected, error
    var color: Color {
        switch self {
        case .unknown: .gray.opacity(0.5)
        case .configured: .yellow
        case .connected: .green
        case .error: .red
        }
    }
}
