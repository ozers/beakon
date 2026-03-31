//
//  CostReportTests.swift
//  BeakonTests
//
//  Created by Ozer on 30.03.2026.
//

import Testing
import Foundation
@testable import Beakon

struct CostReportTests {

    private let sampleCostJSON = """
    {
      "data": [
        {
          "amount_cents": "234.56",
          "description": "Claude API - claude-sonnet-4-20250514, us-east-1, standard",
          "workspace_id": "ws_123"
        },
        {
          "amount_cents": "1050.00",
          "description": "Claude API - claude-opus-4-20250514, us-east-1, standard",
          "workspace_id": null
        }
      ]
    }
    """

    @Test func decodeCostReport() throws {
        let data = Data(sampleCostJSON.utf8)
        let report = try JSONDecoder().decode(CostReport.self, from: data)

        #expect(report.data.count == 2)

        let first = report.data[0]
        #expect(first.amountCents == "234.56")
        #expect(first.description.contains("sonnet"))
        #expect(first.workspaceId == "ws_123")

        let second = report.data[1]
        #expect(second.amountCents == "1050.00")
        #expect(second.workspaceId == nil)
    }

    @Test func amountUSDConversion() throws {
        let data = Data(sampleCostJSON.utf8)
        let report = try JSONDecoder().decode(CostReport.self, from: data)

        let first = report.data[0]
        #expect(first.amountUSD == 2.3456)

        let second = report.data[1]
        #expect(second.amountUSD == 10.50)
    }

    @Test func amountUSDWithInvalidString() throws {
        let json = """
        {"data": [{"amount_cents": "not_a_number", "description": "test", "workspace_id": null}]}
        """
        let report = try JSONDecoder().decode(CostReport.self, from: Data(json.utf8))
        #expect(report.data[0].amountUSD == 0)
    }
}
