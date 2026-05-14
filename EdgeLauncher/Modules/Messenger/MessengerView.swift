import SwiftUI
import WebKit
import os

struct MessengerView: View {
    @ObservedObject private var badges = BadgeStore.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DiscordWebView()
                .ignoresSafeArea()
            if let debugText = badges.debug["messenger"] {
                Text(debugText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                    .padding(12)
            }
        }
    }
}

struct DiscordWebView: NSViewRepresentable {
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
        webView.load(URLRequest(url: URL(string: "https://discord.com/app")!))

        context.coordinator.attach(webView: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject, WKUIDelegate {
        private var timer: Timer?

        func attach(webView: WKWebView) {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak webView] _ in
                guard let webView else { return }
                Task { @MainActor in
                    let title = webView.title ?? ""
                    let titleCount = Self.parseUnread(title: title)
                    webView.evaluateJavaScript("""
                    (function() {
                      try {
                        const sels = [
                          '[class*=numberBadge]',
                          '[class*="numberBadge"]',
                          '[class*=baseShapeRound]'
                        ];
                        let total = 0;
                        for (const s of sels) {
                          const nodes = document.querySelectorAll(s);
                          nodes.forEach(n => {
                            const v = parseInt((n.textContent || '').trim(), 10);
                            if (!isNaN(v)) total += v;
                          });
                          if (total > 0) break;
                        }
                        return total;
                      } catch (e) { return 0; }
                    })();
                    """) { result, _ in
                        let domCount = (result as? Int) ?? 0
                        let finalCount = max(titleCount, domCount)
                        BadgeStore.shared.set("messenger", count: finalCount)
                        BadgeStore.shared.setDebug("messenger", "title=\"\(title.prefix(40))\" t=\(titleCount) dom=\(domCount)")
                        NSApp.dockTile.badgeLabel = finalCount > 0 ? "\(finalCount)" : nil
                        AppLog.web.debug("Discord t=\(titleCount) dom=\(domCount) title=\(title)")
                    }
                }
            }
        }

        deinit { timer?.invalidate() }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        static func parseUnread(title: String) -> Int {
            guard let openIdx = title.firstIndex(of: "("),
                  let closeIdx = title.firstIndex(of: ")"),
                  openIdx < closeIdx else { return 0 }
            let inner = title[title.index(after: openIdx)..<closeIdx]
            return Int(inner) ?? 0
        }
    }
}
