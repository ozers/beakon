//
//  Prompt.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import SwiftData

@Model
final class Prompt {
    var id: UUID
    var title: String
    var content: String
    var category: String?
    var tags: [String]
    var notes: String?
    var isFavorite: Bool
    var usageCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        content: String,
        category: String? = nil,
        tags: [String] = [],
        notes: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.category = category
        self.tags = tags
        self.notes = notes
        self.isFavorite = isFavorite
        self.usageCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var contentPreview: String {
        String(content.prefix(100))
    }

    var formattedDate: String {
        updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    func incrementUsage() {
        usageCount += 1
        updatedAt = Date()
    }
}
