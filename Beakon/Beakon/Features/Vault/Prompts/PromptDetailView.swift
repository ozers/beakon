//
//  PromptDetailView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI

struct PromptDetailView: View {
    let prompt: Prompt
    let onEdit: () -> Void
    @State private var showCopied = false
    @State private var showVariableFill = false

    private var variables: [String] {
        VariableFillView.extractVariables(from: prompt.content)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text(prompt.title)
                        .font(.title2.bold())

                    Spacer()

                    Button {
                        prompt.isFavorite.toggle()
                    } label: {
                        Image(systemName: prompt.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(prompt.isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.borderless)
                }

                // Meta
                HStack(spacing: 12) {
                    if let category = prompt.category {
                        Label(category, systemImage: "folder")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1), in: Capsule())
                    }

                    if !prompt.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(prompt.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Text(prompt.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Divider()

                // Content
                Text(prompt.content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Notes
                if let notes = prompt.notes, !notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Stats
                Divider()
                HStack {
                    Label("\(prompt.usageCount) copies", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem {
                Button("Edit") { onEdit() }
            }

            ToolbarItem {
                Button {
                    copyToClipboard()
                } label: {
                    if showCopied {
                        Label("Copied!", systemImage: "checkmark")
                    } else {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                .keyboardShortcut("c", modifiers: .command)
            }
        }
        .sheet(isPresented: $showVariableFill) {
            VariableFillView(variables: variables, content: prompt.content)
        }
    }

    private func copyToClipboard() {
        if !variables.isEmpty {
            showVariableFill = true
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt.content, forType: .string)
            prompt.incrementUsage()
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showCopied = false
            }
        }
    }
}
