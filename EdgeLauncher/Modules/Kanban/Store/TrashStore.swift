import Foundation

@MainActor
final class TrashStore {
    struct TrashedCard: Codable, Identifiable, Sendable {
        let id: UUID
        let card: KanbanCard
        let boardId: UUID
        let columnId: UUID
        let deletedAt: Date
    }

    private let directory: URL
    private let retentionDays: Int

    init(directory: URL? = nil, retentionDays: Int = 30) {
        let base = directory ?? TrashStore.defaultDirectory()
        self.directory = base
        self.retentionDays = retentionDays
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("EdgeLauncher", isDirectory: true)
            .appendingPathComponent("kanban-trash", isDirectory: true)
    }

    @discardableResult
    func push(card: KanbanCard, boardId: UUID, columnId: UUID) -> TrashedCard {
        let entry = TrashedCard(
            id: card.id,
            card: card,
            boardId: boardId,
            columnId: columnId,
            deletedAt: Date()
        )
        if let data = try? encoder.encode(entry) {
            let url = directory.appendingPathComponent("\(entry.id.uuidString).json")
            try? data.write(to: url, options: .atomic)
        }
        return entry
    }

    func pop(id: UUID) -> TrashedCard? {
        let url = directory.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: url),
              let entry = try? decoder.decode(TrashedCard.self, from: data) else {
            return nil
        }
        try? FileManager.default.removeItem(at: url)
        return entry
    }

    func sweep(referenceDate: Date = Date()) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for url in items where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url),
               let entry = try? decoder.decode(TrashedCard.self, from: data) {
                let ageDays = referenceDate.timeIntervalSince(entry.deletedAt) / 86400
                if ageDays >= Double(retentionDays) {
                    try? fm.removeItem(at: url)
                }
            }
        }
    }

    func list() -> [TrashedCard] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        var entries: [TrashedCard] = []
        for url in items where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url),
               let entry = try? decoder.decode(TrashedCard.self, from: data) {
                entries.append(entry)
            }
        }
        return entries.sorted { $0.deletedAt > $1.deletedAt }
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    private var decoder: JSONDecoder { JSONDecoder() }
}
