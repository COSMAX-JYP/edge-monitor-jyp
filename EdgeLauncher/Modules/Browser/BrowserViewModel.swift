import AppKit
import Combine
import Foundation
import WebKit

@MainActor
final class BrowserViewModel: ObservableObject {
    @Published var displayURL: String = ""
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var pageTitle: String = ""
    @Published var isLoading: Bool = false

    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []

    init(startURL: URL) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.preferences.isElementFullscreenEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        self.webView = webView

        displayURL = startURL.absoluteString
        webView.load(URLRequest(url: startURL))

        observations = [
            webView.observe(\.url, options: [.new]) { [weak self] _, change in
                guard let self else { return }
                let newURL = (change.newValue ?? nil)?.absoluteString ?? ""
                Task { @MainActor in self.displayURL = newURL }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, change in
                guard let self else { return }
                let value = change.newValue ?? false
                Task { @MainActor in self.canGoBack = value }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, change in
                guard let self else { return }
                let value = change.newValue ?? false
                Task { @MainActor in self.canGoForward = value }
            },
            webView.observe(\.title, options: [.new]) { [weak self] _, change in
                guard let self else { return }
                let value = (change.newValue ?? nil) ?? ""
                Task { @MainActor in self.pageTitle = value }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, change in
                guard let self else { return }
                let value = change.newValue ?? false
                Task { @MainActor in self.isLoading = value }
            },
        ]
    }

    deinit {
        observations.forEach { $0.invalidate() }
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }
    func goHome() {
        if let url = URL(string: "https://www.google.com") {
            webView.load(URLRequest(url: url))
        }
    }

    func load(input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let resolved: URL
        if let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https" {
            resolved = url
        } else if Self.looksLikeHost(trimmed) {
            resolved = URL(string: "https://\(trimmed)") ?? Self.searchURL(for: trimmed)
        } else {
            resolved = Self.searchURL(for: trimmed)
        }
        webView.load(URLRequest(url: resolved))
    }

    private static func looksLikeHost(_ s: String) -> Bool {
        guard !s.contains(" ") else { return false }
        guard s.contains(".") else { return false }
        return true
    }

    private static func searchURL(for query: String) -> URL {
        var comps = URLComponents(string: "https://www.google.com/search")!
        comps.queryItems = [URLQueryItem(name: "q", value: query)]
        return comps.url ?? URL(string: "https://www.google.com")!
    }
}
