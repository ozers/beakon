//
//  ProviderIconView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI

struct ProviderIconView: View {
    let providerId: String
    var size: CGFloat = 16

    // Only providers with bundled tray icons
    private static let trayIconAssets: [String: String] = [
        "claude-code": "ProviderClaude",
        "cursor": "ProviderCursor",
        "chatgpt": "ProviderChatGPT",
    ]

    private static let sfSymbols: [String: String] = [
        "claude-code": "terminal",
        "cursor": "cursorarrow.rays",
        "chatgpt": "bubble.left.and.bubble.right",
        "copilot": "airplane",
        "codex": "chevron.left.forwardslash.chevron.right",
        "claude-api": "cloud",
    ]

    var body: some View {
        if let asset = Self.trayIconAssets[providerId] {
            Image(nsImage: {
                let img = NSImage(named: asset) ?? NSImage()
                img.size = NSSize(width: size, height: size)
                return img
            }())
        } else {
            Image(systemName: Self.sfSymbols[providerId] ?? "questionmark.circle")
                .font(.system(size: size * 0.7))
                .frame(width: size, height: size)
        }
    }
}
