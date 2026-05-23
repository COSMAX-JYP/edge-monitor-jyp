import SwiftUI

/// 사이드바 APPS 그리드의 "브라우저" 모듈.
/// EdgeLauncher 메인 프레임 안에 WKWebView 를 직접 임베드 (별도 .app 띄우지 않음).
struct BrowserModule: EdgeModule {
    let id = "browser"
    let title = "브라우저"
    let iconName = "safari.fill"
    let supportsFullscreen = true
    let preservesInactiveRendering = true

    var view: some View { BrowserModuleRootView() }
}

private struct BrowserModuleRootView: View {
    @StateObject private var model = BrowserViewModel(
        startURL: URL(string: "https://www.google.com")!
    )

    var body: some View {
        VStack(spacing: 0) {
            BrowserAddressBar(model: model)
            Divider()
            BrowserWebViewRepresentable(webView: model.webView)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}
