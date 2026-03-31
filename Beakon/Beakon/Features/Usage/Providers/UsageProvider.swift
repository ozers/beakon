//
//  UsageProvider.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation

enum ProviderCredentials: Sendable {
    case apiKey(String)
    case sessionKey(String)
    case oauthToken(String)
}

protocol UsageProvider: AnyObject, Identifiable {
    var id: String { get }
    var name: String { get }
    var iconName: String { get }
    var isConfigured: Bool { get }
    func fetchUsage() async throws -> UsageSnapshot
    func configure(with credentials: ProviderCredentials)
}
