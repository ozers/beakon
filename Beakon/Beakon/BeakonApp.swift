//
//  BeakonApp.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI

@main
struct BeakonApp: App {
    @State private var usageService = UsageService()
    @State private var pollingService: UsagePollingService?
    @State private var hotkeyService: GlobalHotkeyService?
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(usageService: usageService, pollingService: resolvedPollingService)
                .onAppear {
                    startPollingIfNeeded()
                }
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)

        Window("Beakon", id: "main") {
            MainWindowView()
                .environment(usageService)
                .environment(resolvedPollingService)
        }
        .defaultLaunchBehavior(.suppressed)
        .keyboardShortcut("b", modifiers: [.command, .shift])

        Window("About Beakon", id: "about") {
            AboutView()
        }
        .defaultLaunchBehavior(.suppressed)
        .windowResizability(.contentSize)
    }

    private var resolvedPollingService: UsagePollingService {
        if let existing = pollingService {
            return existing
        }
        let service = UsagePollingService(usageService: usageService)
        Task { @MainActor in
            pollingService = service
        }
        return service
    }

    private func startPollingIfNeeded() {
        let service = resolvedPollingService
        if !service.isPolling {
            service.start()
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
