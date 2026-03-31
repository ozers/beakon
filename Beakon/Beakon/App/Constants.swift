//
//  Constants.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation

enum AppConstants {
    static let appName = "Beakon"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    static let githubURL = "https://github.com/ozers/beakon"
    static let defaultPollingInterval: TimeInterval = 300
    static let defaultDailyBudget: Double = 10.0
}
