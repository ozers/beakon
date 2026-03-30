//
//  PromptEditorView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI
import SwiftData

struct PromptEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let prompt: Prompt?

    @State private var title = ""
    @State private var content = ""
    @State private var category = ""
    @State private var tagsText = ""
    @State private var notes = ""
    @State private var showNotes = false

    private var isEditing: Bool { prompt != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text(isEditing ? "Edit Prompt" : "New Prompt")
                    .font(.headline)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.isEmpty || content.isEmpty)
            }
            .padding()

            Divider()

            Form {
                TextField("Title", text: $title)

                VStack(alignment: .leading) {
                    Text("Content")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                }

                TextField("Category", text: $category)

                TextField("Tags (comma separated)", text: $tagsText)

                DisclosureGroup("Notes", isExpanded: $showNotes) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 500)
        .frame(minHeight: 500)
        .onAppear {
            if let prompt {
                title = prompt.title
                content = prompt.content
                category = prompt.category ?? ""
                tagsText = prompt.tags.joined(separator: ", ")
                notes = prompt.notes ?? ""
                showNotes = prompt.notes?.isEmpty == false
            }
        }
    }

    private func save() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let prompt {
            prompt.title = title
            prompt.content = content
            prompt.category = category.isEmpty ? nil : category
            prompt.tags = tags
            prompt.notes = notes.isEmpty ? nil : notes
            prompt.updatedAt = Date()
        } else {
            let newPrompt = Prompt(
                title: title,
                content: content,
                category: category.isEmpty ? nil : category,
                tags: tags,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(newPrompt)
        }

        dismiss()
    }
}
