import WebKit

// YouTube와 YouTube Music이 같은 WKProcessPool을 공유하면
// 동일 Google 계정의 로그인 쿠키와 세션을 더 안정적으로 공유할 수 있다.
enum SharedWebProcessPool {
    static let shared = WKProcessPool()
}
