import Foundation

nonisolated struct GridPosition: Codable, Hashable, Sendable {
    let row: Int
    let col: Int
}

nonisolated struct GridSize: Codable, Hashable, Sendable {
    let rows: Int
    let cols: Int

    static let `default` = GridSize(rows: 3, cols: 12)

    var totalSlots: Int { rows * cols }

    func contains(_ pos: GridPosition) -> Bool {
        pos.row >= 0 && pos.row < rows && pos.col >= 0 && pos.col < cols
    }
}
