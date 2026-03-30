//
//  MainWindowView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI

enum SidebarItem: Hashable {
    case overview
    case provider(String)
    case vault
    case settings
}

struct MainWindowView: View {
    @Environment(UsageService.self) private var usageService
    @Environment(UsagePollingService.self) private var pollingService
    @State private var selectedItem: SidebarItem = .overview
    @State private var sidebarProviders: [(id: String, name: String)] = []

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            detailView
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            sidebarProviders = usageService.configuredProviders.map { (id: $0.id, name: $0.name) }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .overview:
            OverviewDashboardView()
                .environment(usageService)
                .environment(pollingService)
        case .provider(let id):
            ProviderDashboardView(providerId: id)
                .id(id)
                .environment(usageService)
                .environment(pollingService)
        case .vault:
            VaultMainView()
        case .settings:
            SettingsView()
                .environment(usageService)
        }
    }

    private var sidebar: some View {
        List(selection: $selectedItem) {
            Section("Usage") {
                sidebarRow("Overview", icon: "square.grid.2x2", tag: .overview)
            }

            Section("Providers") {
                ForEach(sidebarProviders, id: \.id) { provider in
                    Label {
                        Text(provider.name)
                    } icon: {
                        ProviderIconView(providerId: provider.id, size: 18)
                    }
                    .tag(SidebarItem.provider(provider.id))
                }
            }

            Section("Library") {
                sidebarRow("Prompt Vault", icon: "tray.full", tag: .vault)
            }

            Section {
                sidebarRow("Settings", icon: "gear", tag: .settings)
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarRow(_ title: String, icon: String, tag: SidebarItem) -> some View {
        Label(title, systemImage: icon)
            .tag(tag)
    }
}
