//
//  PromptCardView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI

struct PromptCardView: View {
    let prompt: Prompt

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(prompt.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if prompt.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }

            HStack(spacing: 6) {
                if let category = prompt.category {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                }

                if prompt.usageCount > 0 {
                    Text("\(prompt.usageCount)x used")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(prompt.contentPreview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
