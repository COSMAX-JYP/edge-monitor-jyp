import AppKit
import SwiftUI
import WebKit

struct GenericWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.processPool = SharedWebProcessPool.shared
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.preferences.isElementFullscreenEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.uiDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKUIDelegate {
        private var popupWindows: [NSWindow] = []

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            let popupConfig = WKWebViewConfiguration()
            popupConfig.websiteDataStore = .default()
            popupConfig.processPool = SharedWebProcessPool.shared
            popupConfig.preferences.javaScriptCanOpenWindowsAutomatically = true

            let popup = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 720), configuration: popupConfig)
            popup.uiDelegate = self
            popup.customUserAgent = webView.customUserAgent

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 720),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "로그인"
            window.contentView = popup
            window.center()
            window.makeKeyAndOrderFront(nil)
            popupWindows.append(window)
            return popup
        }

        func webViewDidClose(_ webView: WKWebView) {
            if let idx = popupWindows.firstIndex(where: { $0.contentView === webView }) {
                popupWindows[idx].close()
                popupWindows.remove(at: idx)
            }
        }
    }
}
