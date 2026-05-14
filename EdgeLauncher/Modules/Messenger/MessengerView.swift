import SwiftUI
import WebKit

struct MessengerView: View {
    var body: some View {
        DiscordWebView()
            .ignoresSafeArea()
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

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.load(URLRequest(url: URL(string: "https://discord.com/app")!))

        context.coordinator.attach(webView: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        private var timer: Timer?

        func attach(webView: WKWebView) {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak webView] _ in
                guard let webView else { return }
                Task { @MainActor in
                    let title = webView.title ?? ""
                    let count = Self.parseUnread(title: title)
                    BadgeStore.shared.set("messenger", count: count)
                }
            }
        }

        deinit { timer?.invalidate() }

        // "(5) Discord | ..." 또는 "(5) #channel | Server | Discord" 형식에서 N 추출
        static func parseUnread(title: String) -> Int {
            guard let openIdx = title.firstIndex(of: "("),
                  let closeIdx = title.firstIndex(of: ")"),
                  openIdx < closeIdx else { return 0 }
            let inner = title[title.index(after: openIdx)..<closeIdx]
            return Int(inner) ?? 0
        }
    }
}
