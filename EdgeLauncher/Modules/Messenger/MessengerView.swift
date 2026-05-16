import SwiftUI
import WebKit
import os

struct MessengerView: View {
    let config: MessengerInstanceConfig
    @ObservedObject private var badges = BadgeStore.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DiscordWebView(config: config)
                .ignoresSafeArea()
            if let debugText = badges.debug[config.id] {
                Text(debugText)
                    .font(.appCaptionMono)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                    .padding(12)
            }
        }
    }
}

struct DiscordWebView: NSViewRepresentable {
    let config: MessengerInstanceConfig

    func startURL() -> URL {
        return Self.resolveStartURL(input: UserDefaults.standard.string(forKey: config.urlKey) ?? "")
    }

    /// 현재 페이지 URL 과 시작 URL 이 같은 Discord 채널을 가리키는지 비교.
    /// 채널 경로 `/channels/<guild>/<channel>` 까지만 비교하므로 thread 등 하위 경로도 같은 채널로 간주.
    static func isSameChannel(current: URL?, target: URL) -> Bool {
        guard let current else { return false }
        // 둘 다 discord.com 도메인에 있을 때만 의미가 있다.
        guard (current.host ?? "").contains("discord.com"),
              (target.host ?? "").contains("discord.com") else {
            return current.absoluteString == target.absoluteString
        }
        let currentKey = channelKey(from: current)
        let targetKey = channelKey(from: target)
        return currentKey == targetKey
    }

    /// 경로에서 `/channels/<guild>/<channel>` 부분만 추출 (없으면 전체 path).
    private static func channelKey(from url: URL) -> String {
        let comps = url.path.split(separator: "/").map(String.init)
        if comps.count >= 3, comps[0].lowercased() == "channels" {
            return "channels/\(comps[1])/\(comps[2])"
        }
        return url.path
    }

    /// 사용자가 입력한 다양한 포맷을 Discord URL 로 정규화한다.
    /// - 전체 URL (`https://discord.com/...`) → 그대로
    /// - `channels/<guild>/<channel>` 형태 → `https://discord.com/channels/...`
    /// - `<guild>/<channel>` (숫자/숫자) → 길드 채널로 매핑
    /// - `@me/<id>` → DM 채널
    /// - 숫자만 (`<channelID>`) → DM 으로 추정 (`@me/<id>`)
    /// - 빈 문자열 → 기본 페이지
    static func resolveStartURL(input: String) -> URL {
        let fallback = URL(string: "https://discord.com/app")!
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return fallback }

        if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://"),
           let url = URL(string: raw) {
            return url
        }

        // 슬래시로 분리.
        let segments = raw.split(separator: "/").map(String.init)

        // "channels/<guild>/<channel>" 또는 "channels/@me/<channel>"
        if segments.count >= 3, segments[0].lowercased() == "channels" {
            let guild = segments[1]
            let channel = segments[2]
            return URL(string: "https://discord.com/channels/\(guild)/\(channel)") ?? fallback
        }

        // "<guild>/<channel>" 또는 "@me/<channel>"
        if segments.count == 2 {
            let guild = segments[0]
            let channel = segments[1]
            return URL(string: "https://discord.com/channels/\(guild)/\(channel)") ?? fallback
        }

        // 숫자만 → DM 추정.
        if segments.count == 1, segments[0].allSatisfy(\.isNumber) {
            return URL(string: "https://discord.com/channels/@me/\(segments[0])") ?? fallback
        }

        return fallback
    }

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        // 인스턴스별 격리된 데이터 저장소 → 서로 다른 Discord 계정 로그인 가능.
        if #available(macOS 14.0, *) {
            cfg.websiteDataStore = WKWebsiteDataStore(forIdentifier: config.storageUUID)
        } else {
            cfg.websiteDataStore = .default()
        }
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.allowsAirPlayForMediaPlayback = true
        cfg.preferences.isElementFullscreenEnabled = true
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: cfg)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.uiDelegate = context.coordinator
        webView.load(URLRequest(url: startURL()))

        context.coordinator.attach(webView: webView, instanceID: config.id)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
        nsView.uiDelegate = nil
        nsView.stopLoading()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject, WKUIDelegate {
        private var timer: Timer?
        private var instanceID: String = "messenger"
        private weak var webView: WKWebView?
        private var reloadObserver: NSObjectProtocol?

        func attach(webView: WKWebView, instanceID: String) {
            self.instanceID = instanceID
            self.webView = webView
            timer?.invalidate()
            let id = instanceID

            // Settings 에서 "저장 및 새로고침" 요청을 받으면 새 URL 로 다시 로드.
            reloadObserver = NotificationCenter.default.addObserver(
                forName: .discordReloadRequested,
                object: nil,
                queue: .main
            ) { [weak webView] note in
                guard let webView else { return }
                guard let targetID = note.userInfo?["instanceID"] as? String, targetID == id else { return }
                guard let cfg = MessengerInstanceConfig.find(by: id) else { return }
                let targetURL = DiscordWebView.resolveStartURL(input: UserDefaults.standard.string(forKey: cfg.urlKey) ?? "")
                let forced = (note.userInfo?["force"] as? Bool) ?? false
                if !forced, DiscordWebView.isSameChannel(current: webView.url, target: targetURL) {
                    return  // 이미 같은 채널이면 reload 스킵
                }
                webView.load(URLRequest(url: targetURL))
            }
            timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak webView] _ in
                guard let webView else { return }
                Task { @MainActor in
                    let title = webView.title ?? ""
                    let titleCount = Self.parseUnread(title: title)
                    let result = try? await webView.evaluateJavaScript("""
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
                    """)
                    let domCount = (result as? Int) ?? 0
                    let finalCount = max(titleCount, domCount)
                    BadgeStore.shared.set(id, count: finalCount)
                    BadgeStore.shared.setDebug(id, "title=\"\(title.prefix(40))\" t=\(titleCount) dom=\(domCount)")
                    AppLog.web.debug("Discord(\(id)) t=\(titleCount) dom=\(domCount) title=\(title)")
                }
            }
        }

        func detach() {
            timer?.invalidate()
            timer = nil
            if let observer = reloadObserver {
                NotificationCenter.default.removeObserver(observer)
                reloadObserver = nil
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
