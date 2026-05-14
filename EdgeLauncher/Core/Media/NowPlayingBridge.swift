import Foundation

// WKWebView가 MediaSession API를 macOS Now Playing 위젯과 미디어 키에 자동 전달한다.
// 동작이 미흡하면 MPRemoteCommandCenter + MPNowPlayingInfoCenter로 JS 브리지를 통해
// 곡 정보를 직접 전달하는 확장을 추가한다. MVP에서는 WebKit 기본 동작에 의존.
enum NowPlayingBridge {
    static let placeholder = "see Task 16 follow-up"
}
