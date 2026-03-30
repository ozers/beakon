//
//  CursorWebLoginView.swift
//  Beakon
//
//  Created by Ozer on 31.03.2026.
//

import SwiftUI
import WebKit

struct CursorWebLoginView: View {
    var scraper: CursorWebScraper
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Connect to Cursor")
                    .font(.headline)
                Spacer()
                if scraper.isLoading { ProgressView().controlSize(.small) }
                Button("Done") { dismiss() }
            }
            .padding()
            Divider()
            CursorWebViewWrapper(scraper: scraper)
            if let usage = scraper.lastUsage {
                HStack {
                    Label("Total \(usage.totalPercent)%", systemImage: "checkmark.circle.fill")
                    Spacer()
                    Label("Composer \(usage.composerPercent)%", systemImage: "checkmark.circle.fill")
                }
                .font(.caption).foregroundStyle(.green)
                .padding(8).background(.green.opacity(0.1))
            }
        }
        .frame(width: 500, height: 600)
        .onAppear { scraper.loadSettingsPage() }
    }
}

struct CursorWebViewWrapper: NSViewRepresentable {
    let scraper: CursorWebScraper
    func makeNSView(context: Context) -> WKWebView { scraper.createWebView() }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
