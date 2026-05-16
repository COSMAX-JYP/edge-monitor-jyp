import Foundation
import AppKit

/// 사이드바 모듈의 아이콘을 커스텀 이미지 파일로 교체할 때 쓰는 설정.
/// SF Symbol 만 쓰는 경우는 nil 이고, 사용자가 이미지를 지정했을 때만 값이 채워진다.
struct IconCustomization: Equatable {
    let imagePath: String
    let scale: Double      // 0.5 ~ 1.5 (1.0 = 원본 크기)
    let offsetX: Double    // -30 ~ 30 pt
    let offsetY: Double    // -30 ~ 30 pt

    /// 파일이 실제로 존재하는지 검사.
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: imagePath)
    }

    /// `~/Library/Application Support/EdgeLauncher/icons/` 에 저장된 이미지 파일을 로드.
    func loadImage() -> NSImage? {
        guard fileExists else { return nil }
        return NSImage(contentsOfFile: imagePath)
    }
}

/// 커스텀 아이콘 파일을 보관하는 디렉토리.
enum IconStorage {
    /// `~/Library/Application Support/EdgeLauncher/icons/`
    static var directory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("EdgeLauncher/icons", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 사용자가 선택한 파일을 모듈 ID 로 복사 → 저장된 절대 경로를 반환.
    @discardableResult
    static func install(sourceURL: URL, moduleID: String) throws -> URL {
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension.lowercased()
        let destination = directory.appendingPathComponent("\(moduleID).\(ext)")
        // 이전 파일 정리.
        try? removeAllVariants(moduleID: moduleID)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    static func remove(moduleID: String) throws {
        try removeAllVariants(moduleID: moduleID)
    }

    private static func removeAllVariants(moduleID: String) throws {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in contents where url.deletingPathExtension().lastPathComponent == moduleID {
            try? fm.removeItem(at: url)
        }
    }
}

enum ModuleIconCustomizationStore {
    static func customization(for moduleID: String, defaults: UserDefaults = .standard) -> IconCustomization? {
        let path = (defaults.string(forKey: imageKey(moduleID)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
        let scale = defaults.object(forKey: scaleKey(moduleID)) as? Double ?? 1.0
        let offsetX = defaults.object(forKey: offsetXKey(moduleID)) as? Double ?? 0
        let offsetY = defaults.object(forKey: offsetYKey(moduleID)) as? Double ?? 0
        return IconCustomization(imagePath: path, scale: scale, offsetX: offsetX, offsetY: offsetY)
    }

    static func save(_ customization: IconCustomization, for moduleID: String, defaults: UserDefaults = .standard) {
        defaults.set(customization.imagePath, forKey: imageKey(moduleID))
        defaults.set(customization.scale, forKey: scaleKey(moduleID))
        defaults.set(customization.offsetX, forKey: offsetXKey(moduleID))
        defaults.set(customization.offsetY, forKey: offsetYKey(moduleID))
        NotificationCenter.default.post(name: .moduleIconChanged, object: nil)
    }

    static func clear(for moduleID: String, defaults: UserDefaults = .standard) {
        try? IconStorage.remove(moduleID: moduleID)
        defaults.removeObject(forKey: imageKey(moduleID))
        defaults.removeObject(forKey: scaleKey(moduleID))
        defaults.removeObject(forKey: offsetXKey(moduleID))
        defaults.removeObject(forKey: offsetYKey(moduleID))
        NotificationCenter.default.post(name: .moduleIconChanged, object: nil)
    }

    static func migrateLegacyDiscordIcons(defaults: UserDefaults = .standard) {
        for id in ["messenger", "messenger-2", "messenger-3"] where defaults.string(forKey: imageKey(id)) == nil {
            let legacyImageKey = "app.\(id).iconImage"
            let path = (defaults.string(forKey: legacyImageKey) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { continue }
            defaults.set(path, forKey: imageKey(id))
            defaults.set(defaults.object(forKey: "app.\(id).iconScale") as? Double ?? 1.0, forKey: scaleKey(id))
            defaults.set(defaults.object(forKey: "app.\(id).iconOffsetX") as? Double ?? 0, forKey: offsetXKey(id))
            defaults.set(defaults.object(forKey: "app.\(id).iconOffsetY") as? Double ?? 0, forKey: offsetYKey(id))
        }
    }

    static func imageKey(_ moduleID: String) -> String { "app.moduleIcon.\(moduleID).image" }
    static func scaleKey(_ moduleID: String) -> String { "app.moduleIcon.\(moduleID).scale" }
    static func offsetXKey(_ moduleID: String) -> String { "app.moduleIcon.\(moduleID).offsetX" }
    static func offsetYKey(_ moduleID: String) -> String { "app.moduleIcon.\(moduleID).offsetY" }
}

extension Notification.Name {
    static let moduleIconChanged = Notification.Name("edge.module.iconChanged")
}
