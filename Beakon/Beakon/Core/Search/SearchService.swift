//
//  SearchService.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import SwiftData

struct SearchService {
    let modelContext: ModelContext

    func search(query: String) throws -> [Prompt] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return try modelContext.fetch(
                FetchDescriptor<Prompt>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            )
        }

        let lowercased = query.lowercased()

        let predicate = #Predicate<Prompt> { prompt in
            prompt.title.localizedStandardContains(lowercased) ||
            prompt.content.localizedStandardContains(lowercased) ||
            (prompt.notes?.localizedStandardContains(lowercased) ?? false)
        }

        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    func fetchByCategory(_ category: String?) throws -> [Prompt] {
        if let category {
            let predicate = #Predicate<Prompt> { prompt in
                prompt.category == category
            }
            return try modelContext.fetch(
                FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            )
        } else {
            return try modelContext.fetch(
                FetchDescriptor<Prompt>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            )
        }
    }

    func fetchFavorites() throws -> [Prompt] {
        let predicate = #Predicate<Prompt> { prompt in
            prompt.isFavorite == true
        }
        return try modelContext.fetch(
            FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        )
    }

    func allCategories() throws -> [String] {
        let all = try modelContext.fetch(FetchDescriptor<Prompt>())
        let categories = Set(all.compactMap { $0.category })
        return categories.sorted()
    }
}
