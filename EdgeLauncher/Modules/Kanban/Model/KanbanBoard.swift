import Foundation

struct KanbanBoard: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var colorHex: String
    var columns: [KanbanColumn]
    var labels: [KanbanLabel]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#4A90E2",
        columns: [KanbanColumn] = [],
        labels: [KanbanLabel] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.columns = columns
        self.labels = labels
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
