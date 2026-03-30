//
//  FirstLaunchService.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation

struct FirstLaunchService {
    private static let hasLaunchedKey = "hasLaunchedBefore"

    static var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: hasLaunchedKey)
    }

    static func markLaunched() {
        UserDefaults.standard.set(true, forKey: hasLaunchedKey)
    }
}
