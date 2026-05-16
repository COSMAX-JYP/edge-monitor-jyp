import Foundation

nonisolated struct WebhookTemplate: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var summary: String
    var method: HTTPMethod
    var urlPlaceholder: String
    var headers: [WebhookHeader]
    var bodyTemplate: String
    var iconSymbol: String

    static let presets: [WebhookTemplate] = [
        WebhookTemplate(
            id: "slack",
            name: "Slack 인커밍 웹훅",
            summary: "Slack 채널에 메시지 게시",
            method: .post,
            urlPlaceholder: "https://hooks.slack.com/services/...",
            headers: [WebhookHeader(name: "Content-Type", value: "application/json")],
            bodyTemplate: #"{"text": "EdgeLauncher 에서 보냄"}"#,
            iconSymbol: "bubble.left.and.bubble.right"
        ),
        WebhookTemplate(
            id: "discord",
            name: "Discord 웹훅",
            summary: "Discord 채널에 메시지 전송",
            method: .post,
            urlPlaceholder: "https://discord.com/api/webhooks/...",
            headers: [WebhookHeader(name: "Content-Type", value: "application/json")],
            bodyTemplate: #"{"content": "EdgeLauncher 에서 알림", "username": "EdgeLauncher"}"#,
            iconSymbol: "gamecontroller"
        ),
        WebhookTemplate(
            id: "ntfy",
            name: "ntfy.sh 알림",
            summary: "ntfy 토픽에 푸시 알림",
            method: .post,
            urlPlaceholder: "https://ntfy.sh/your-topic",
            headers: [
                WebhookHeader(name: "Title", value: "EdgeLauncher"),
                WebhookHeader(name: "Priority", value: "default"),
                WebhookHeader(name: "Tags", value: "rocket")
            ],
            bodyTemplate: "버튼이 눌렸습니다",
            iconSymbol: "bell.badge"
        ),
        WebhookTemplate(
            id: "ifttt",
            name: "IFTTT 웹훅",
            summary: "IFTTT Maker Webhook 트리거",
            method: .post,
            urlPlaceholder: "https://maker.ifttt.com/trigger/{event}/with/key/{key}",
            headers: [WebhookHeader(name: "Content-Type", value: "application/json")],
            bodyTemplate: #"{"value1": "EdgeLauncher"}"#,
            iconSymbol: "shippingbox"
        ),
        WebhookTemplate(
            id: "github_dispatch",
            name: "GitHub repository_dispatch",
            summary: "GitHub Actions repository_dispatch 이벤트 발사",
            method: .post,
            urlPlaceholder: "https://api.github.com/repos/{owner}/{repo}/dispatches",
            headers: [
                WebhookHeader(name: "Accept", value: "application/vnd.github+json"),
                WebhookHeader(name: "Authorization", value: "Bearer {GITHUB_TOKEN}"),
                WebhookHeader(name: "X-GitHub-Api-Version", value: "2022-11-28")
            ],
            bodyTemplate: #"{"event_type": "edge-launcher-button"}"#,
            iconSymbol: "chevron.left.forwardslash.chevron.right"
        ),
        WebhookTemplate(
            id: "home_assistant",
            name: "Home Assistant 서비스 호출",
            summary: "Home Assistant 의 services API 호출",
            method: .post,
            urlPlaceholder: "https://homeassistant.local:8123/api/services/{domain}/{service}",
            headers: [
                WebhookHeader(name: "Authorization", value: "Bearer {LONG_LIVED_TOKEN}"),
                WebhookHeader(name: "Content-Type", value: "application/json")
            ],
            bodyTemplate: #"{"entity_id": "light.living_room"}"#,
            iconSymbol: "house"
        ),
        WebhookTemplate(
            id: "generic_json_post",
            name: "일반 JSON POST",
            summary: "JSON body 를 POST 로 전송",
            method: .post,
            urlPlaceholder: "https://example.com/webhook",
            headers: [WebhookHeader(name: "Content-Type", value: "application/json")],
            bodyTemplate: #"{"key": "value"}"#,
            iconSymbol: "curlybraces"
        ),
        WebhookTemplate(
            id: "generic_get",
            name: "GET 핑",
            summary: "URL 에 단순 GET 호출",
            method: .get,
            urlPlaceholder: "https://example.com/ping",
            headers: [],
            bodyTemplate: "",
            iconSymbol: "arrow.up.right.circle"
        )
    ]

    static func find(id: String) -> WebhookTemplate? {
        presets.first { $0.id == id }
    }
}
