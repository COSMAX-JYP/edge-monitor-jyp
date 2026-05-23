import AppKit
import SwiftUI
import WebKit

struct BrowserWebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView.uiDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKUIDelegate {
        // 새 창 요청: 사용자 제스처로 트리거된 경우만 같은 webView 에서 로드.
        // 임의 페이지가 사용자 제스처 없이 현재 페이지를 팝업 URL 로 대체하는 것은 차단.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil else { return nil }
            guard let url = navigationAction.request.url else { return nil }
            guard isUserInitiated(navigationAction) else { return nil }
            webView.load(URLRequest(url: url))
            return nil
        }

        private func isUserInitiated(_ action: WKNavigationAction) -> Bool {
            switch action.navigationType {
            case .linkActivated, .formSubmitted, .backForward, .reload, .formResubmitted:
                return true
            default:
                return false
            }
        }
    }
}
