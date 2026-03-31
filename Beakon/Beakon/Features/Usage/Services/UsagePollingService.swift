//
//  UsagePollingService.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import os

@Observable
@MainActor
final class UsagePollingService {
    private(set) var isPolling = false
    private(set) var lastRefreshDate: Date?

    private var timer: Timer?
    private let usageService: UsageService
    private let notificationService = NotificationService()
    private let logger = Logger(subsystem: "com.beakon", category: "Polling")

    var pollingInterval: TimeInterval {
        let stored = UserDefaults.standard.integer(forKey: "pollingInterval")
        return stored > 0 ? TimeInterval(stored) : 600
    }

    init(usageService: UsageService) {
        self.usageService = usageService
    }

    func start() {
        guard !isPolling else { return }
        isPolling = true
        notificationService.requestPermission()
        logger.info("Polling started (interval: \(self.pollingInterval)s)")
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isPolling = false
        logger.info("Polling stopped")
    }

    func refresh() async {
        logger.info("Polling refresh triggered")
        await usageService.refreshAll()

        if usageService.lastError == nil {
            lastRefreshDate = Date()
            if let snapshot = usageService.currentSnapshot {
                notificationService.checkThresholds(snapshot: snapshot)
            }
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refresh()
            }
        }
    }

    func restartWithCurrentInterval() {
        stop()
        start()
    }
}
