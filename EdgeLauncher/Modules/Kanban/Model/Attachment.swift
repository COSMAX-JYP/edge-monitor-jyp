import Foundation

struct Attachment: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var path: String
    var displayName: String
    var addedAt: Date

    init(id: UUID = UUID(), path: String, displayName: String? = nil, addedAt: Date = Date()) {
        self.id = id
        self.path = path
        self.displayName = displayName ?? URL(fileURLWithPath: path).lastPathComponent
        self.addedAt = addedAt
    }

    var fileURL: URL { URL(fileURLWithPath: path) }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }
    var isImage: Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "heic", "webp", "bmp"].contains(ext)
    }
}
