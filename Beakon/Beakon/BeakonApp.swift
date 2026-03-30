//
//  BeakonApp.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI
import SwiftData

@main
struct BeakonApp: App {
    @State private var usageService = UsageService()
    @State private var pollingService: UsagePollingService?
    @State private var historyService: UsageHistoryService?
    @State private var hotkeyService: GlobalHotkeyService?
    @Environment(\.openWindow) private var openWindow

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            UsageHistoryEntry.self,
            Prompt.self,
        ])

        let iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

        let modelConfiguration: ModelConfiguration
        if iCloudEnabled {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
        } else {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(usageService: usageService, pollingService: resolvedPollingService)
                .modelContainer(sharedModelContainer)
                .onAppear {
                    startPollingIfNeeded()
                    handleFirstLaunch()
                }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(usageService)
        }

        Window("Beakon", id: "main") {
            MainWindowView()
                .environment(usageService)
                .environment(resolvedPollingService)
                .modelContainer(sharedModelContainer)
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
        Image("MenuBarIcon")
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

    private func handleFirstLaunch() {
        if FirstLaunchService.isFirstLaunch {
            FirstLaunchService.markLaunched()
            // Open settings on first launch so user can enter API key
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }

    private func startPollingIfNeeded() {
        let service = resolvedPollingService
        if !service.isPolling {
            service.start()
        }

        // Register global hotkey ⌘+Shift+B
        if hotkeyService == nil {
            hotkeyService = GlobalHotkeyService { [self] in
                openWindow(id: "main")
                NSApp.activate()
            }
            hotkeyService?.register()
        }

        // Initialize history service and wire up recording
        if historyService == nil {
            let hs = UsageHistoryService(modelContext: sharedModelContainer.mainContext)
            historyService = hs
            usageService.onSnapshotUpdate = { snapshot in
                hs.record(snapshot: snapshot)
            }
        }
    }
}
