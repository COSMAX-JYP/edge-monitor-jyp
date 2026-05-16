import Foundation

struct KanbanColumn: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var colorHex: String?
    var cards: [KanbanCard]

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String? = nil,
        cards: [KanbanCard] = []
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.cards = cards
    }
}
