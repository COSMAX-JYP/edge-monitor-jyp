import SwiftUI
import WebKit

struct YouTubeWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.preferences.isElementFullscreenEnabled = true

        let doubleTapScript = """
        (function() {
          let lastTap = 0; let lastX = 0;
          document.addEventListener('touchend', function(e) {
            const now = Date.now();
            const x = e.changedTouches[0].clientX;
            if (now - lastTap < 350 && Math.abs(x - lastX) < 60) {
              const video = document.querySelector('video');
              if (video) {
                const w = window.innerWidth;
                if (x < w / 2) video.currentTime = Math.max(0, video.currentTime - 10);
                else video.currentTime = Math.min(video.duration, video.currentTime + 10);
              }
              lastTap = 0;
            } else {
              lastTap = now; lastX = x;
            }
          }, { passive: true });
        })();
        """
        let userScript = WKUserScript(source: doubleTapScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}
