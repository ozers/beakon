//
//  ClaudeWebLoginView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI
import WebKit

struct ClaudeWebLoginView: View {
    var scraper: ClaudeWebScraper
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Connect to claude.ai")
                    .font(.headline)
                Spacer()
                if scraper.isLoading {
                    ProgressView().controlSize(.small)
                }
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            WebViewWrapper(scraper: scraper)

            if let error = scraper.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Retry") { scraper.loadUsagePage() }
                        .controlSize(.small)
                }
                .padding(8)
                .background(.red.opacity(0.1))
            }

            if let usage = scraper.lastUsage {
                HStack {
                    Label("Session: \(usage.sessionPercent)%", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                    Spacer()
                    Label("Weekly: \(usage.weeklyPercent)%", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                }
                .padding(8)
                .background(.green.opacity(0.1))
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            scraper.loadUsagePage()
        }
    }
}

struct WebViewWrapper: NSViewRepresentable {
    let scraper: ClaudeWebScraper

    func makeNSView(context: Context) -> WKWebView {
        scraper.createWebView()
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
