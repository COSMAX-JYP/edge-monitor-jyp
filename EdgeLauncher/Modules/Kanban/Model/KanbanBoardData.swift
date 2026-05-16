import Foundation

struct KanbanBoardData: Codable, Versioned, Sendable {
    static var schemaVersion: Int { 1 }

    var boards: [KanbanBoard]
    var activeBoardId: UUID?

    static func makeDefault() -> KanbanBoardData {
        let board = KanbanBoard.makeDefault()
        return KanbanBoardData(boards: [board], activeBoardId: board.id)
    }
}
