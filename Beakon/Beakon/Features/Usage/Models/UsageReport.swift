//
//  UsageReport.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation

struct UsageReport: Codable, Sendable {
    let data: [UsageBucket]

    struct UsageBucket: Codable, Sendable {
        let startTime: String
        let endTime: String
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationInputTokens: Int
        let cacheReadInputTokens: Int
        let model: String?
        let workspaceId: String?

        enum CodingKeys: String, CodingKey {
            case startTime = "start_time"
            case endTime = "end_time"
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case model
            case workspaceId = "workspace_id"
        }
    }
}
