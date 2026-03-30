//
//  ExportImportService.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import SwiftData

enum ImportMode {
    case merge
    case replace
}

struct ImportResult: Sendable {
    let importedCount: Int
    let skippedCount: Int
    let errors: [String]
}

struct ExportImportService {
    private static let schemaVersion = "1.0"

    func exportAll(prompts: [Prompt]) throws -> Data {
        let exportPrompts = prompts.map { prompt in
            ExportPrompt(
                id: prompt.id.uuidString,
                title: prompt.title,
                content: prompt.content,
                category: prompt.category,
                tags: prompt.tags,
                notes: prompt.notes,
                isFavorite: prompt.isFavorite,
                usageCount: prompt.usageCount,
                createdAt: prompt.createdAt,
                updatedAt: prompt.updatedAt
            )
        }

        let export = ExportContainer(
            version: Self.schemaVersion,
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            app: "Beakon",
            data: ExportData(
                prompts: exportPrompts,
                boilerplates: [],
                bookmarks: []
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    func importFromJSON(data: Data, mode: ImportMode, modelContext: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let container = try decoder.decode(ExportContainer.self, from: data)

        if mode == .replace {
            let existing = try modelContext.fetch(FetchDescriptor<Prompt>())
            for prompt in existing {
                modelContext.delete(prompt)
            }
        }

        var imported = 0
        var skipped = 0
        var errors: [String] = []

        let existingIDs: Set<String>
        if mode == .merge {
            let all = try modelContext.fetch(FetchDescriptor<Prompt>())
            existingIDs = Set(all.map { $0.id.uuidString })
        } else {
            existingIDs = []
        }

        for exportPrompt in container.data.prompts {
            if mode == .merge && existingIDs.contains(exportPrompt.id) {
                skipped += 1
                continue
            }

            guard let uuid = UUID(uuidString: exportPrompt.id) else {
                errors.append("Invalid UUID: \(exportPrompt.id)")
                continue
            }

            let prompt = Prompt(
                title: exportPrompt.title,
                content: exportPrompt.content,
                category: exportPrompt.category,
                tags: exportPrompt.tags,
                notes: exportPrompt.notes,
                isFavorite: exportPrompt.isFavorite
            )
            prompt.id = uuid
            prompt.usageCount = exportPrompt.usageCount
            prompt.createdAt = exportPrompt.createdAt
            prompt.updatedAt = exportPrompt.updatedAt

            modelContext.insert(prompt)
            imported += 1
        }

        try modelContext.save()
        return ImportResult(importedCount: imported, skippedCount: skipped, errors: errors)
    }
}

// MARK: - Export Schema

private struct ExportContainer: Codable {
    let version: String
    let exportedAt: String
    let app: String
    let data: ExportData
}

private struct ExportData: Codable {
    let prompts: [ExportPrompt]
    let boilerplates: [String] // Empty for now
    let bookmarks: [String]    // Empty for now
}

private struct ExportPrompt: Codable {
    let id: String
    let title: String
    let content: String
    let category: String?
    let tags: [String]
    let notes: String?
    let isFavorite: Bool
    let usageCount: Int
    let createdAt: Date
    let updatedAt: Date
}
