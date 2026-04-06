//
//  BeakonApp.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI

@main
struct BeakonApp: App {
    @State private var usageService: UsageService
    @State private var pollingService: UsagePollingService
    @State private var hotkeyService: GlobalHotkeyService?
    @Environment(\.openWindow) private var openWindow

    init() {
        let usage = UsageService()
        _usageService = State(initialValue: usage)
        _pollingService = State(initialValue: UsagePollingService(usageService: usage))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(usageService: usageService, pollingService: pollingService)
        } label: {
            menuBarLabel
                .onAppear {
                    startPollingIfNeeded()
                }
        }
        .menuBarExtraStyle(.window)

        Window("Beakon", id: "main") {
            MainWindowView()
                .environment(usageService)
                .environment(pollingService)
        }
        .defaultLaunchBehavior(.suppressed)
        .keyboardShortcut("b", modifiers: [.command, .shift])

        Window("About Beakon", id: "about") {
            AboutView()
        }
        .defaultLaunchBehavior(.suppressed)
        .windowResizability(.contentSize)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        let providerId = UserDefaults.standard.string(forKey: "defaultProvider") ?? "claude-code"
        if let snap = usageService.cachedSnapshot(for: providerId),
           let limits = snap.limits,
           let primary = limits.items.first(where: { $0.style == .bar }) {
            HStack(spacing: 3) {
                Image("MenuBarIcon")
                Text("\(primary.percent)%")
                    .font(.caption2.monospacedDigit())
            }
        } else {
            Image("MenuBarIcon")
        }
    }

    private func startPollingIfNeeded() {
        if !pollingService.isPolling {
            pollingService.start()
        }

        if hotkeyService == nil {
            hotkeyService = GlobalHotkeyService { [self] in
                openWindow(id: "main")
                NSApp.activate()
            }
            hotkeyService?.register()
        }
    }
}
