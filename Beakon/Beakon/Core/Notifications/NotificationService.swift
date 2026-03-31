//
//  NotificationService.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import UserNotifications
import os

@MainActor
final class NotificationService {
    private let logger = Logger(subsystem: "com.beakon", category: "Notifications")
    private var sentThresholds: Set<Int> = []

    func requestPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                logger.info("Notification permission: \(granted)")
            } catch {
                logger.error("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func checkThresholds(snapshot: UsageSnapshot) {
        let warningLevel = UserDefaults.standard.integer(forKey: "warningThreshold")
        let criticalLevel = UserDefaults.standard.integer(forKey: "criticalThreshold")
        let warning = warningLevel > 0 ? warningLevel : 75
        let critical = criticalLevel > 0 ? criticalLevel : 90

        // Simple cost-based percentage (using $10/day default budget)
        let dailyBudget = 10.0
        let percentage = Int((snapshot.totalCostUSD / dailyBudget) * 100)

        if percentage >= critical && !sentThresholds.contains(critical) {
            sentThresholds.insert(critical)
            sendNotification(
                title: "Usage Critical — \(percentage)%",
                body: "You've used $\(String(format: "%.2f", snapshot.totalCostUSD)) of your daily budget."
            )
        } else if percentage >= warning && !sentThresholds.contains(warning) {
            sentThresholds.insert(warning)
            sendNotification(
                title: "Usage Warning — \(percentage)%",
                body: "You've used $\(String(format: "%.2f", snapshot.totalCostUSD)) of your daily budget."
            )
        }
    }

    func resetThresholds() {
        sentThresholds.removeAll()
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "beakon-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error {
                logger.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
}
