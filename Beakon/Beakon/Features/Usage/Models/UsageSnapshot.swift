//
//  UsageSnapshot.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation

struct UsageSnapshot: Sendable {
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCostUSD: Double
    let periodStart: Date
    let periodEnd: Date
    let modelBreakdown: [ModelUsage]
    let dailyMessageCounts: [DailyCount]
    let sessionInfo: SessionInfo?
    let weeklyMessageCount: Int
    let projectBreakdown: [ProjectUsage]
    let limits: ProviderLimits?
    let planName: String?
    let authStatus: AuthStatus

    init(
        totalInputTokens: Int,
        totalOutputTokens: Int,
        totalCostUSD: Double,
        periodStart: Date,
        periodEnd: Date,
        modelBreakdown: [ModelUsage],
        dailyMessageCounts: [DailyCount] = [],
        sessionInfo: SessionInfo? = nil,
        weeklyMessageCount: Int = 0,
        projectBreakdown: [ProjectUsage] = [],
        limits: ProviderLimits? = nil,
        planName: String? = nil,
        authStatus: AuthStatus = .authenticated
    ) {
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens
        self.totalCostUSD = totalCostUSD
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.modelBreakdown = modelBreakdown
        self.dailyMessageCounts = dailyMessageCounts
        self.sessionInfo = sessionInfo
        self.weeklyMessageCount = weeklyMessageCount
        self.projectBreakdown = projectBreakdown
        self.limits = limits
        self.planName = planName
        self.authStatus = authStatus
    }

    var totalTokens: Int { totalInputTokens + totalOutputTokens }
    var messageCount: Int { totalInputTokens }
    var sessionCount: Int { totalOutputTokens }

    struct ModelUsage: Sendable {
        let model: String
        let inputTokens: Int
        let outputTokens: Int
        let costUSD: Double
    }

    struct ProjectUsage: Sendable {
        let name: String
        let messageCount: Int
    }
}

// MARK: - Provider Limits

struct ProviderLimits: Sendable {
    let items: [LimitItem]

    struct LimitItem: Sendable {
        let title: String
        let percent: Int
        let detail: String
        let style: Style

        enum Style: Sendable {
            case bar       // percentage progress bar
            case spending  // dollar amount display
        }

        init(title: String, percent: Int, detail: String, style: Style = .bar) {
            self.title = title
            self.percent = percent
            self.detail = detail
            self.style = style
        }
    }
}

enum AuthStatus: Sendable {
    case authenticated
    case notAuthenticated(hint: String)
    case expired
}

struct DailyCount: Sendable {
    let date: Date
    let count: Int
}

struct SessionInfo: Sendable {
    let startedAt: Date
    let messageCount: Int
    let resetsAt: Date // 5-hour window from start

    var minutesRemaining: Int {
        max(0, Int(resetsAt.timeIntervalSinceNow / 60))
    }

    var hoursMinutesRemaining: String {
        let mins = minutesRemaining
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins)m"
    }

    var elapsed: String {
        let mins = Int(Date().timeIntervalSince(startedAt) / 60)
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins)m"
    }
}
