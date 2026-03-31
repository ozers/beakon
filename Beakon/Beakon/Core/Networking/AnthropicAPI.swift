//
//  AnthropicAPI.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation

struct AnthropicAPI: Sendable {
    private static let baseURL = "https://api.anthropic.com"
    private static let apiVersion = "2023-06-01"

    private let apiKey: String
    private let client: APIClient

    init(apiKey: String, client: APIClient = APIClient()) {
        self.apiKey = apiKey
        self.client = client
    }

    private var headers: [String: String] {
        [
            "x-api-key": apiKey,
            "anthropic-version": Self.apiVersion,
            "content-type": "application/json",
        ]
    }

    /// Fetch usage report from Anthropic Admin API
    /// - Parameters:
    ///   - startingAt: ISO 8601 datetime string
    ///   - endingAt: ISO 8601 datetime string
    ///   - bucketWidth: "1m", "1h", or "1d"
    ///   - groupBy: Optional grouping ("model", "workspace_id", "api_key", "service_tier")
    func fetchUsageReport(
        startingAt: String,
        endingAt: String,
        bucketWidth: String = "1d",
        groupBy: String? = nil
    ) async throws -> UsageReport {
        var params: [String: String] = [
            "starting_at": startingAt,
            "ending_at": endingAt,
            "bucket_width": bucketWidth,
        ]
        if let groupBy {
            params["group_by"] = groupBy
        }

        return try await client.get(
            url: "\(Self.baseURL)/v1/organizations/usage_report/messages",
            headers: headers,
            queryParams: params
        )
    }

    /// Fetch cost report from Anthropic Admin API
    /// - Parameters:
    ///   - startingAt: ISO 8601 datetime string
    ///   - endingAt: ISO 8601 datetime string
    ///   - groupBy: Optional grouping (e.g., "workspace_id", "description")
    func fetchCostReport(
        startingAt: String,
        endingAt: String,
        groupBy: [String]? = nil
    ) async throws -> CostReport {
        var params: [String: String] = [
            "starting_at": startingAt,
            "ending_at": endingAt,
        ]
        if let groupBy {
            for group in groupBy {
                params["group_by[]"] = group
            }
        }

        return try await client.get(
            url: "\(Self.baseURL)/v1/organizations/cost_report",
            headers: headers,
            queryParams: params
        )
    }
}
