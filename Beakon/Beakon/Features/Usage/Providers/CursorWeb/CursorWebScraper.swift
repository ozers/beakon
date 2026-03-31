//
//  CursorWebScraper.swift
//  Beakon
//
//  Created by Ozer on 31.03.2026.
//

import Foundation
import WebKit
import os

struct CursorWebUsage: Codable, Sendable {
    var totalPercent: Int
    var composerPercent: Int
    var apiPercent: Int
    var planName: String
    var resetDate: String
    var lastFetched: Date?
}

@Observable
@MainActor
final class CursorWebScraper: NSObject {
    var isLoggedIn = false
    var isLoading = false
    var lastUsage: CursorWebUsage?
    var error: String?

    private var webView: WKWebView?
    private var hiddenWebView: WKWebView?
    private let logger = Logger(subsystem: "com.beakon", category: "CursorWeb")
    private let settingsURL = URL(string: "https://www.cursor.com/settings")!

    private let extractJS = """
    (function() {
        const r = {totalPercent:0, composerPercent:0, apiPercent:0, planName:'', resetDate:''};
        const t = document.body?.innerText || '';

        // Plan name
        const plan = t.match(/CURRENT PLAN\\s*\\n\\s*(\\w+)/i);
        if (plan) r.planName = plan[1];

        // Reset date
        const reset = t.match(/Resets on\\s+(.+?)\\s*\\(/i);
        if (reset) r.resetDate = reset[1].trim();

        // Percentages: Total X%, then Auto + Composer X%, API X%
        const allPercents = [...t.matchAll(/(\\d+)%/g)];
        if (allPercents.length >= 1) r.totalPercent = parseInt(allPercents[0][1]);

        // Find "Auto + Composer" percentage and "API" percentage
        const composerMatch = t.match(/Auto \\+ Composer[\\s\\S]*?(\\d+)%/i);
        if (composerMatch) r.composerPercent = parseInt(composerMatch[1]);

        const apiMatch = t.match(/API[\\s\\S]*?(\\d+)%/i);
        if (apiMatch) r.apiPercent = parseInt(apiMatch[1]);

        return JSON.stringify(r);
    })()
    """

    func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        self.webView = wv
        return wv
    }

    func loadSettingsPage() {
        guard let webView else { return }
        isLoading = true
        error = nil
        webView.load(URLRequest(url: settingsURL))
    }

    func refreshSilently() {
        isLoading = true
        error = nil
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let hidden = WKWebView(frame: .init(x: 0, y: 0, width: 1, height: 1), configuration: config)
        hidden.navigationDelegate = self
        self.hiddenWebView = hidden
        hidden.load(URLRequest(url: settingsURL))
    }

    func checkLoginStatus() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            let hasCursor = cookies.contains { $0.domain.contains("cursor.com") }
            Task { @MainActor in
                self?.isLoggedIn = hasCursor
                if hasCursor { self?.lastUsage = self?.loadFromCache() }
            }
        }
    }

    private func handleExtraction(result: Any?, error: Error?) {
        isLoading = false
        if let error { logger.error("JS failed: \(error.localizedDescription)"); return }
        guard let jsonString = result as? String,
              let data = jsonString.data(using: .utf8) else { return }

        logger.info("Cursor JS: \(jsonString)")

        do {
            var usage = try JSONDecoder().decode(CursorWebUsage.self, from: data)
            usage.lastFetched = Date()
            if usage.totalPercent > 0 || usage.composerPercent > 0 {
                lastUsage = usage
                isLoggedIn = true
                self.error = nil
                saveToCache(usage)
                logger.info("Cursor usage: total=\(usage.totalPercent)% composer=\(usage.composerPercent)% api=\(usage.apiPercent)%")
            }
        } catch {
            logger.error("Parse: \(error.localizedDescription)")
        }
    }

    func saveToCache(_ usage: CursorWebUsage) {
        if let data = try? JSONEncoder().encode(usage) {
            UserDefaults.standard.set(data, forKey: "cachedCursorWebUsage")
        }
    }

    func loadFromCache() -> CursorWebUsage? {
        guard let data = UserDefaults.standard.data(forKey: "cachedCursorWebUsage") else { return nil }
        return try? JSONDecoder().decode(CursorWebUsage.self, from: data)
    }
}

extension CursorWebScraper: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            isLoading = false
            error = nil
            if let url = webView.url, url.host?.contains("cursor.com") == true,
               url.path.contains("settings") {
                try? await Task.sleep(for: .seconds(2))
                let result = try? await webView.evaluateJavaScript(extractJS)
                handleExtraction(result: result, error: nil)
                if webView == hiddenWebView { hiddenWebView = nil }
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            isLoading = false
            if (error as NSError).code != NSURLErrorCancelled { self.error = error.localizedDescription }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            isLoading = false
            if (error as NSError).code != NSURLErrorCancelled { self.error = error.localizedDescription }
        }
    }
}
