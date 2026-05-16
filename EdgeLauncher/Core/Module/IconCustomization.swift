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
