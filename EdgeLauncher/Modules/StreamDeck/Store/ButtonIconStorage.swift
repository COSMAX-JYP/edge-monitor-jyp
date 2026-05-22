import Foundation
import AppKit
import UniformTypeIdentifiers

/// On-disk storage for user-supplied button icons.
///
/// Images are copied into `Application Support/EdgeLauncher/ButtonIcons/{uuid}.{ext}`
/// so the original file can be moved or deleted without breaking the launcher.
@MainActor
final class ButtonIconStorage {
    static let shared = ButtonIconStorage()

    private let directoryURL: URL
    private let fileManager: FileManager
    private var cache: [String: NSImage] = [:]
    private let supportedTypes: [UTType] = [.png, .jpeg, .tiff, .gif, .bmp, .heic, .webP, .svg, .image]

    init(
        directoryURL: URL = ButtonIconStorage.defaultDirectory(),
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    nonisolated static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("EdgeLauncher", isDirectory: true)
            .appendingPathComponent("ButtonIcons", isDirectory: true)
    }

    /// Copy an image from `sourceURL` into the storage directory and return the stored filename.
    @discardableResult
    func store(sourceURL: URL) throws -> String {
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension.lowercased()
        let filename = "\(UUID().uuidString).\(ext)"
        let destination = directoryURL.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return filename
    }

    func url(forFilename filename: String) -> URL {
        directoryURL.appendingPathComponent(filename)
    }

    func image(forFilename filename: String) -> NSImage? {
        guard !filename.isEmpty else { return nil }
        if let cached = cache[filename] { return cached }
        let url = self.url(forFilename: filename)
        guard fileManager.fileExists(atPath: url.path),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        cache[filename] = image
        return image
    }

    func remove(filename: String) {
        cache.removeValue(forKey: filename)
        let url = self.url(forFilename: filename)
        try? fileManager.removeItem(at: url)
    }

    func clearCache() {
        cache.removeAll()
    }

    /// Allowed file types when presenting an `NSOpenPanel`.
    var allowedContentTypes: [UTType] { supportedTypes }
}
