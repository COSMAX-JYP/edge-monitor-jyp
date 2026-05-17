import SwiftUI

struct MessengerInstanceConfig {
    let id: String
    let defaultTitle: String
    let storageUUID: UUID  // WKWebsiteDataStore 식별자 (세션 분리)

    var urlKey: String { "app.\(id).startURL" }
    var titleKey: String { "app.\(id).title" }
    var iconKey: String { "app.\(id).icon" }
    var iconImageKey: String { "app.\(id).iconImage" }       // 절대 경로
    var iconScaleKey: String { "app.\(id).iconScale" }       // Double, default 1.0
    var iconOffsetXKey: String { "app.\(id).iconOffsetX" }   // Double, default 0
    var iconOffsetYKey: String { "app.\(id).iconOffsetY" }   // Double, default 0

    static let allInstances: [MessengerInstanceConfig] = [
        MessengerInstanceConfig(
            id: "messenger",
            defaultTitle: "Discord",
            storageUUID: UUID(uuidString: "DC0001CD-D15C-4A11-B0A1-DC0001000001")!
        ),
        MessengerInstanceConfig(
            id: "messenger-2",
            defaultTitle: "Discord 2",
            storageUUID: UUID(uuidString: "DC0002CD-D15C-4A11-B0A1-DC0002000002")!
        ),
        MessengerInstanceConfig(
            id: "messenger-3",
            defaultTitle: "Discord 3",
            storageUUID: UUID(uuidString: "DC0003CD-D15C-4A11-B0A1-DC0003000003")!
        ),
        MessengerInstanceConfig(
            id: "messenger-4",
            defaultTitle: "JYP봇",
            storageUUID: UUID(uuidString: "DC0004CD-D15C-4A11-B0A1-DC0004000004")!
        ),
    ]

    static func find(by id: String) -> MessengerInstanceConfig? {
        allInstances.first { $0.id == id }
    }
}

struct MessengerModule: EdgeModule {
    let config: MessengerInstanceConfig

    var id: String { config.id }
    var title: String {
        let stored = UserDefaults.standard.string(forKey: config.titleKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? config.defaultTitle : stored
    }
    var iconName: String {
        let stored = UserDefaults.standard.string(forKey: config.iconKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? "bubble.left.and.bubble.right.fill" : stored
    }
    let supportsFullscreen = true
    let preservesInactiveRendering = true

    var iconCustomization: IconCustomization? {
        let defaults = UserDefaults.standard
        let path = (defaults.string(forKey: config.iconImageKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
        let scale = defaults.object(forKey: config.iconScaleKey) as? Double ?? 1.0
        let dx = defaults.object(forKey: config.iconOffsetXKey) as? Double ?? 0
        let dy = defaults.object(forKey: config.iconOffsetYKey) as? Double ?? 0
        return IconCustomization(imagePath: path, scale: scale, offsetX: dx, offsetY: dy)
    }

    var view: some View { MessengerView(config: config) }

    func didBecomeActive() {
        // 탭이 활성화될 때마다 지정된 시작 URL 로 다시 로드.
        NotificationCenter.default.post(
            name: .discordReloadRequested,
            object: nil,
            userInfo: ["instanceID": config.id]
        )
    }
}
