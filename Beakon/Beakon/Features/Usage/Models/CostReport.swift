//
//  CostReport.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation

struct CostReport: Codable, Sendable {
    let data: [CostLineItem]

    struct CostLineItem: Codable, Sendable {
        let amountCents: String
        let description: String
        let workspaceId: String?

        enum CodingKeys: String, CodingKey {
            case amountCents = "amount_cents"
            case description
            case workspaceId = "workspace_id"
        }

        var amountUSD: Double {
            guard let cents = Double(amountCents) else { return 0 }
            return cents / 100.0
        }
    }
}
