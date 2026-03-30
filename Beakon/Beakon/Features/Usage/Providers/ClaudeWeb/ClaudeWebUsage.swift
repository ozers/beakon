//
//  ClaudeWebUsage.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation

struct ClaudeWebUsage: Codable, Sendable {
    var sessionPercent: Int
    var sessionResetsIn: String
    var weeklyPercent: Int
    var weeklyResetsOn: String
    var extraUsageSpent: Double
    var extraUsageLimit: Double
    var extraUsagePercent: Int
    var lastFetched: Date?

    enum CodingKeys: String, CodingKey {
        case sessionPercent, sessionResetsIn
        case weeklyPercent, weeklyResetsOn
        case extraUsageSpent, extraUsageLimit, extraUsagePercent
        case lastFetched
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionPercent = try c.decodeIfPresent(Int.self, forKey: .sessionPercent) ?? 0
        sessionResetsIn = try c.decodeIfPresent(String.self, forKey: .sessionResetsIn) ?? "--"
        weeklyPercent = try c.decodeIfPresent(Int.self, forKey: .weeklyPercent) ?? 0
        weeklyResetsOn = try c.decodeIfPresent(String.self, forKey: .weeklyResetsOn) ?? "--"
        extraUsageSpent = try c.decodeIfPresent(Double.self, forKey: .extraUsageSpent) ?? 0
        extraUsageLimit = try c.decodeIfPresent(Double.self, forKey: .extraUsageLimit) ?? 0
        extraUsagePercent = try c.decodeIfPresent(Int.self, forKey: .extraUsagePercent) ?? 0
        lastFetched = try c.decodeIfPresent(Date.self, forKey: .lastFetched)
    }
}
