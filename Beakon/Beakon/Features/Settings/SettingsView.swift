//
//  SettingsView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var warningThreshold = UserDefaults.standard.integer(forKey: "warningThreshold") == 0 ? 75 : UserDefaults.standard.integer(forKey: "warningThreshold")
    @State private var criticalThreshold = UserDefaults.standard.integer(forKey: "criticalThreshold") == 0 ? 90 : UserDefaults.standard.integer(forKey: "criticalThreshold")
    @State private var pollingInterval = UserDefaults.standard.integer(forKey: "pollingInterval") == 0 ? 600 : UserDefaults.standard.integer(forKey: "pollingInterval")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.largeTitle.bold())

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
}
