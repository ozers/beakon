//
//  VaultMainView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct VaultMainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedCategory: String? = nil
    @State private var selectedPrompt: Prompt?
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var editingPrompt: Prompt?
    @State private var showFavoritesOnly = false
    @State private var showingImporter = false
    @State private var sortOrder: PromptSortOrder = .recent

    private var prompts: [Prompt] {
        let service = SearchService(modelContext: modelContext)
        var results: [Prompt]
        do {
            if !searchText.isEmpty {
                results = try service.search(query: searchText)
            } else if showFavoritesOnly {
                results = try service.fetchFavorites()
            } else {
                results = try service.fetchByCategory(selectedCategory)
            }
        } catch { results = [] }

        switch sortOrder {
        case .recent: return results.sorted { $0.updatedAt > $1.updatedAt }
        case .mostUsed: return results.sorted { $0.usageCount > $1.usageCount }
        case .alphabetical: return results.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                filterMenu

                TextField("Search prompts...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)

                Picker("Sort", selection: $sortOrder) {
                    ForEach(PromptSortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .frame(width: 100)

                Spacer()

                Button {
                    editingPrompt = nil
                    showingEditor = true
                } label: {
                    Label("New", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)

                Menu {
                    Button("Export All...") { exportPrompts() }
                    Button("Import...") { showingImporter = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .padding(12)

            Divider()

            // Content
            if prompts.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(.quaternary)
                    Text("No Prompts")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Create your first prompt to get started")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Button("New Prompt") {
                        editingPrompt = nil
                        showingEditor = true
                    }
                }
                Spacer()
            } else {
                List(prompts, id: \.id, selection: $selectedPrompt) { prompt in
                    HStack(spacing: 10) {
                        if prompt.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption2)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(prompt.title)
                                .font(.body)
                                .lineLimit(1)
                            Text(prompt.contentPreview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if let cat = prompt.category {
                            Text(cat)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.15), in: Capsule())
                                .foregroundStyle(.blue)
                        }

                        Text("\(prompt.usageCount)x")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .tag(prompt)
                    .contextMenu {
                        Button("Edit") { editingPrompt = prompt; showingEditor = true }
                        Button("Copy") { copyPrompt(prompt) }
                        Divider()
                        Button(prompt.isFavorite ? "Unfavorite" : "Favorite") { prompt.isFavorite.toggle() }
                        Divider()
                        Button("Delete", role: .destructive) { modelContext.delete(prompt) }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            PromptEditorView(prompt: editingPrompt)
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
    }

    // MARK: - Filter

    private var filterMenu: some View {
        Menu {
            Button { showFavoritesOnly = false; selectedCategory = nil } label: {
                Label("All Prompts", systemImage: "tray.full")
            }
            Button { showFavoritesOnly = true; selectedCategory = nil } label: {
                Label("Favorites", systemImage: "star.fill")
            }
            let cats = (try? SearchService(modelContext: modelContext).allCategories()) ?? []
            if !cats.isEmpty {
                Divider()
                ForEach(cats, id: \.self) { cat in
                    Button { showFavoritesOnly = false; selectedCategory = cat } label: {
                        Label(cat, systemImage: "folder")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showFavoritesOnly ? "star.fill" : (selectedCategory != nil ? "folder" : "line.3.horizontal.decrease.circle"))
                Text(showFavoritesOnly ? "Favorites" : (selectedCategory ?? "All"))
                    .font(.subheadline)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Actions

    private func copyPrompt(_ prompt: Prompt) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.content, forType: .string)
        prompt.incrementUsage()
    }

    private func exportPrompts() {
        do {
            let data = try ExportImportService().exportAll(
                prompts: modelContext.fetch(FetchDescriptor<Prompt>())
            )
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "beakon-prompts.json"
            if panel.runModal() == .OK, let url = panel.url { try data.write(to: url) }
        } catch {}
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let _ = try ExportImportService().importFromJSON(
                data: Data(contentsOf: url), mode: .merge, modelContext: modelContext
            )
        } catch {}
    }
}
