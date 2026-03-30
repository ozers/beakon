//
//  ClaudeWebScraper.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import WebKit
import os

@Observable
@MainActor
final class ClaudeWebScraper: NSObject {
    var isLoggedIn = false
    var isLoading = false
    var lastUsage: ClaudeWebUsage?
    var error: String?

    private var webView: WKWebView?
    private let logger = Logger(subsystem: "com.beakon", category: "ClaudeWeb")
    private let usageURL = URL(string: "https://claude.ai/settings/usage")!

    // JavaScript to extract usage data from the page
    private let extractJS = """
    (function() {
        const r = {
            sessionPercent: 0, sessionResetsIn: '--',
            weeklyPercent: 0, weeklyResetsOn: '--',
            extraUsageSpent: 0, extraUsageLimit: 0, extraUsagePercent: 0
        };

        const t = document.body?.innerText || '';

        // Find all "X% used" patterns in order — 1st=session, 2nd+=weekly/extra
        const allPercents = [...t.matchAll(/(\\d+)%\\s*used/gi)];
        if (allPercents.length >= 1) r.sessionPercent = parseInt(allPercents[0][1]);
        if (allPercents.length >= 2) r.weeklyPercent = parseInt(allPercents[1][1]);
        if (allPercents.length >= 4) r.extraUsagePercent = parseInt(allPercents[3][1]);

        // "Resets in X min" or "Resets in X hr X min"
        const allResets = [...t.matchAll(/Resets\\s+(?:in\\s+)?([^\\n]+)/gi)];
        if (allResets.length >= 1) r.sessionResetsIn = allResets[0][1].trim();
        if (allResets.length >= 2) r.weeklyResetsOn = allResets[1][1].trim();

        // "$X.XX spent"
        const spent = t.match(/\\$(\\d+\\.\\d+)\\s*spent/i);
        if (spent) r.extraUsageSpent = parseFloat(spent[1]);

        // "$X" right before "Monthly spend limit"
        const limit = t.match(/\\$(\\d+)\\s*\\n*\\s*Monthly spend limit/i);
        if (limit) r.extraUsageLimit = parseFloat(limit[1]);

        return JSON.stringify(r);
    })()
    """

    func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // Persist cookies
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        self.webView = wv
        return wv
    }

    func loadUsagePage() {
        guard let webView else { return }
        isLoading = true
        error = nil
        webView.load(URLRequest(url: usageURL))
    }

    /// Silent refresh — uses a hidden WebView, no UI shown
    func refreshSilently() {
        isLoading = true
        error = nil
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let hidden = WKWebView(frame: .init(x: 0, y: 0, width: 1, height: 1), configuration: config)
        hidden.navigationDelegate = self
        self.hiddenWebView = hidden
        hidden.load(URLRequest(url: usageURL))
    }

    private var hiddenWebView: WKWebView?

    func extractUsage() {
        guard let webView else { return }
        isLoading = true
        Task {
            let result = try? await webView.evaluateJavaScript(extractJS)
            handleExtraction(result: result, error: nil)
        }
    }

    private func handleExtraction(result: Any?, error: Error?) {
        isLoading = false

        if let error {
            logger.error("JS extraction failed: \(error.localizedDescription)")
            return
        }

        guard let jsonString = result as? String,
              let data = jsonString.data(using: .utf8) else {
            logger.error("JS returned non-string: \(String(describing: result))")
            return
        }

        logger.info("JS extracted: \(jsonString)")

        do {
            var usage = try JSONDecoder().decode(ClaudeWebUsage.self, from: data)
            usage.lastFetched = Date()

            if usage.sessionPercent > 0 || usage.weeklyPercent > 0 {
                lastUsage = usage
                isLoggedIn = true
                self.error = nil
                saveToCache(usage)
                logger.info("Usage extracted: session=\(usage.sessionPercent)% weekly=\(usage.weeklyPercent)%")
            } else {
                logger.info("Page loaded but no usage data found yet")
            }
        } catch {
            logger.error("Parse error: \(error.localizedDescription)")
        }
    }

    // Cache to UserDefaults so we have data between launches
    private func saveToCache(_ usage: ClaudeWebUsage) {
        if let data = try? JSONEncoder().encode(usage) {
            UserDefaults.standard.set(data, forKey: "cachedClaudeWebUsage")
        }
    }

    func loadFromCache() -> ClaudeWebUsage? {
        guard let data = UserDefaults.standard.data(forKey: "cachedClaudeWebUsage"),
              let usage = try? JSONDecoder().decode(ClaudeWebUsage.self, from: data) else {
            return nil
        }
        return usage
    }

    func checkLoginStatus() {
        // Check if we have cookies for claude.ai
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            let hasClaude = cookies.contains { $0.domain.contains("claude.ai") }
            Task { @MainActor in
                self?.isLoggedIn = hasClaude
                if hasClaude {
                    self?.lastUsage = self?.loadFromCache()
                }
            }
        }
    }
}

extension ClaudeWebScraper: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            isLoading = false
            error = nil

            if let url = webView.url, url.path.contains("settings/usage") {
                try? await Task.sleep(for: .seconds(2))

                // Use whichever webView loaded the page
                let targetWV = (webView == hiddenWebView) ? hiddenWebView : self.webView
                guard let targetWV else { return }

                let result = try? await targetWV.evaluateJavaScript(extractJS)
                handleExtraction(result: result, error: nil)
                if webView == hiddenWebView {
                    hiddenWebView = nil
                }
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            isLoading = false
            // Only show error if it's not a cancelled navigation (e.g. redirect)
            if (error as NSError).code != NSURLErrorCancelled {
                self.error = error.localizedDescription
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            isLoading = false
            if (error as NSError).code != NSURLErrorCancelled {
                self.error = error.localizedDescription
            }
        }
    }
}
