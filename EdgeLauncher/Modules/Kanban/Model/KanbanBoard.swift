import Foundation

struct KanbanBoard: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var colorHex: String
    var columns: [KanbanColumn]
    var labels: [KanbanLabel]
    var hiddenCardIds: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#4A90E2",
        columns: [KanbanColumn] = [],
        labels: [KanbanLabel] = [],
        hiddenCardIds: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.columns = columns
        self.labels = labels
        self.hiddenCardIds = hiddenCardIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#4A90E2"
        self.columns = try c.decodeIfPresent([KanbanColumn].self, forKey: .columns) ?? []
        self.labels = try c.decodeIfPresent([KanbanLabel].self, forKey: .labels) ?? []
        self.hiddenCardIds = try c.decodeIfPresent([UUID].self, forKey: .hiddenCardIds) ?? []
        self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    static func makeDefault() -> KanbanBoard {
        KanbanBoard(
            name: "기본 보드",
            columns: [
                KanbanColumn(name: "TODO"),
                KanbanColumn(name: "Doing"),
                KanbanColumn(name: "Review"),
                KanbanColumn(name: "Blocked"),
                KanbanColumn(name: "Done")
            ]
        )
    }
}
