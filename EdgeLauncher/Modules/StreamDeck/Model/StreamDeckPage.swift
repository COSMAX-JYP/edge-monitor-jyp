import Foundation

nonisolated struct StreamDeckPage: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var colorHex: String
    var gridSize: GridSize
    var buttons: [StreamDeckButton]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "기본",
        colorHex: String = "#4A90E2",
        gridSize: GridSize = .default,
        buttons: [StreamDeckButton] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.gridSize = gridSize
        self.buttons = buttons
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func button(at position: GridPosition) -> StreamDeckButton? {
        buttons.first { $0.position == position }
    }
}

nonisolated struct StreamDeckData: Codable, Versioned, Sendable {
    static var schemaVersion: Int { 1 }
    var pages: [StreamDeckPage]
    var activePageId: UUID?

    static func makeDefault() -> StreamDeckData {
        let page = StreamDeckPage()
        return StreamDeckData(pages: [page], activePageId: page.id)
    }
}
