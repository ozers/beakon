//
//  PromptListView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI
import SwiftData

enum PromptSortOrder: String, CaseIterable {
    case recent = "Recent"
    case mostUsed = "Most Used"
    case alphabetical = "A–Z"
}

struct PromptListView: View {
    @Environment(\.modelContext) private var modelContext
    let category: String?
    let searchText: String
    let favoritesOnly: Bool
    @Binding var selectedPrompt: Prompt?
    let onEdit: (Prompt) -> Void
    let onNew: () -> Void

    @State private var sortOrder: PromptSortOrder = .recent

    private var prompts: [Prompt] {
        let service = SearchService(modelContext: modelContext)
        var results: [Prompt]

        do {
            if !searchText.isEmpty {
                results = try service.search(query: searchText)
            } else if favoritesOnly {
                results = try service.fetchFavorites()
            } else {
                results = try service.fetchByCategory(category)
            }
        } catch {
            results = []
        }

        switch sortOrder {
        case .recent:
            return results.sorted { $0.updatedAt > $1.updatedAt }
        case .mostUsed:
            return results.sorted { $0.usageCount > $1.usageCount }
        case .alphabetical:
            return results.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        Group {
            if prompts.isEmpty {
                ContentUnavailableView {
                    Label("No Prompts", systemImage: "doc.text")
                } description: {
                    Text("Create your first prompt!")
                } actions: {
                    Button("New Prompt") { onNew() }
                }
            } else {
                List(prompts, id: \.id, selection: $selectedPrompt) { prompt in
                    PromptCardView(prompt: prompt)
                        .tag(prompt)
                        .contextMenu {
                            Button("Edit") { onEdit(prompt) }
                            Button("Copy") { copyPrompt(prompt) }
                            Divider()
                            Button(prompt.isFavorite ? "Unfavorite" : "Favorite") {
                                prompt.isFavorite.toggle()
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                deletePrompt(prompt)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deletePrompt(prompt)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                prompt.isFavorite.toggle()
                            } label: {
                                Label(
                                    prompt.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: prompt.isFavorite ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Picker("Sort", selection: $sortOrder) {
                    ForEach(PromptSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
            }
        }
    }

    private func copyPrompt(_ prompt: Prompt) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.content, forType: .string)
        prompt.incrementUsage()
    }

    private func deletePrompt(_ prompt: Prompt) {
        if selectedPrompt?.id == prompt.id {
            selectedPrompt = nil
        }
        modelContext.delete(prompt)
    }
}
