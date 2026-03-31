//
//  UsageReportTests.swift
//  BeakonTests
//
//  Created by Ozer on 30.03.2026.
//

import Testing
import Foundation
@testable import Beakon

struct UsageReportTests {

    private let sampleUsageJSON = """
    {
      "data": [
        {
          "start_time": "2026-03-30T00:00:00Z",
          "end_time": "2026-03-30T01:00:00Z",
          "input_tokens": 15000,
          "output_tokens": 5000,
          "cache_creation_input_tokens": 1000,
          "cache_read_input_tokens": 2000,
          "model": "claude-sonnet-4-20250514",
          "workspace_id": "ws_123"
        },
        {
          "start_time": "2026-03-30T01:00:00Z",
          "end_time": "2026-03-30T02:00:00Z",
          "input_tokens": 20000,
          "output_tokens": 8000,
          "cache_creation_input_tokens": 0,
          "cache_read_input_tokens": 500,
          "model": "claude-opus-4-20250514",
          "workspace_id": null
        }
      ]
    }
    """

    @Test func decodeUsageReport() throws {
        let data = Data(sampleUsageJSON.utf8)
        let report = try JSONDecoder().decode(UsageReport.self, from: data)

        #expect(report.data.count == 2)

        let first = report.data[0]
        #expect(first.inputTokens == 15000)
        #expect(first.outputTokens == 5000)
        #expect(first.cacheCreationInputTokens == 1000)
        #expect(first.cacheReadInputTokens == 2000)
        #expect(first.model == "claude-sonnet-4-20250514")
        #expect(first.workspaceId == "ws_123")
        #expect(first.startTime == "2026-03-30T00:00:00Z")

        let second = report.data[1]
        #expect(second.inputTokens == 20000)
        #expect(second.outputTokens == 8000)
        #expect(second.model == "claude-opus-4-20250514")
        #expect(second.workspaceId == nil)
    }

    @Test func decodeEmptyUsageReport() throws {
        let json = """
        {"data": []}
        """
        let report = try JSONDecoder().decode(UsageReport.self, from: Data(json.utf8))
        #expect(report.data.isEmpty)
    }
}
