//
//  VariableFillView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI

struct VariableFillView: View {
    let variables: [String]
    let content: String
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String] = [:]
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Fill Variables")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(variables, id: \.self) { variable in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(variable)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TextField("Enter \(variable)...", text: binding(for: variable))
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Divider()

                    Text("Preview")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(filledContent)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                }
                .padding()
            }

            Divider()

            HStack {
                Spacer()
                Button(copied ? "Copied!" : "Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(filledContent, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(variables.contains { values[$0]?.isEmpty ?? true })
            }
            .padding()
        }
        .frame(width: 450)
        .frame(minHeight: 350)
    }

    private func binding(for variable: String) -> Binding<String> {
        Binding(
            get: { values[variable] ?? "" },
            set: { values[variable] = $0 }
        )
    }

    private var filledContent: String {
        var result = content
        for (variable, value) in values {
            result = result.replacingOccurrences(of: "{{\(variable)}}", with: value)
        }
        return result
    }

    static func extractVariables(from content: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}")
        let matches = regex?.matches(in: content, range: NSRange(content.startIndex..., in: content)) ?? []
        let variables = matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: content) else { return nil }
            return String(content[range]).trimmingCharacters(in: .whitespaces)
        }
        return Array(Set(variables)).sorted()
    }
}
