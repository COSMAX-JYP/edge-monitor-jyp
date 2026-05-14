import SwiftUI
import WebKit

struct OutlookCalendarView: View {
    var body: some View {
        OutlookCalendarWebView()
            .ignoresSafeArea()
    }
}

struct OutlookCalendarWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.processPool = SharedWebProcessPool.shared
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.load(URLRequest(url: URL(string: "https://outlook.office.com/calendar/view/month")!))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
