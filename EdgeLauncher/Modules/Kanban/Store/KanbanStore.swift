import Foundation
import Observation

@Observable
@MainActor
final class KanbanStore {
    @ObservationIgnored
    private let backing: AtomicJSONStore<KanbanBoardData>

    @ObservationIgnored
    let dataURL: URL

    var data: KanbanBoardData { backing.value }

    init(url: URL? = nil) {
        let location = url ?? KanbanStore.defaultURL()
        self.dataURL = location
        self.backing = AtomicJSONStore<KanbanBoardData>(
            url: location,
            default: KanbanBoardData.makeDefault(),
            debounce: .milliseconds(400),
            errorCategory: "Kanban",
            migrate: { version, _ in
                throw SchemaMigrationError.unsupportedVersion(version, supported: KanbanBoardData.schemaVersion)
            }
        )
        if backing.value.boards.isEmpty {
            backing.replace(KanbanBoardData.makeDefault())
        } else if backing.value.activeBoardId == nil,
                  let first = backing.value.boards.first {
            backing.update { $0.activeBoardId = first.id }
        }
    }

    func findColumnId(forCard cardId: UUID, boardId: UUID? = nil) -> (boardId: UUID, columnId: UUID)? {
        let bid = boardId ?? data.activeBoardId
        for board in data.boards where bid == nil || board.id == bid {
            for column in board.columns {
                if column.cards.contains(where: { $0.id == cardId }) {
                    return (board.id, column.id)
                }
            }
        }
        return nil
    }

    static func defaultURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("EdgeLauncher", isDirectory: true)
            .appendingPathComponent("kanban.json")
    }

    func flush() async throws {
        try await backing.flush()
    }

    // MARK: - Board

    var activeBoard: KanbanBoard? {
        guard let id = data.activeBoardId else { return data.boards.first }
        return data.boards.first { $0.id == id }
    }

    func setActiveBoard(_ id: UUID) {
        backing.update { $0.activeBoardId = id }
    }

    func addBoard(_ board: KanbanBoard) {
        backing.update {
            $0.boards.append(board)
            $0.activeBoardId = board.id
        }
    }

    func renameBoard(_ id: UUID, name: String) {
        backing.update { data in
            guard let idx = data.boards.firstIndex(where: { $0.id == id }) else { return }
            data.boards[idx].name = name
            data.boards[idx].updatedAt = Date()
        }
    }

    func deleteBoard(_ id: UUID) {
        backing.update { data in
            data.boards.removeAll { $0.id == id }
            if data.activeBoardId == id {
                data.activeBoardId = data.boards.first?.id
            }
        }
        backing.flushSyncNow()
    }

    // MARK: - Card

    func addCard(_ card: KanbanCard, to columnId: UUID) {
        mutateActiveBoard { board in
            guard let idx = board.columns.firstIndex(where: { $0.id == columnId }) else { return }
            board.columns[idx].cards.append(card)
        }
    }

    func updateCard(_ card: KanbanCard) {
        mutateActiveBoard { board in
            for (colIdx, col) in board.columns.enumerated() {
                if let cardIdx = col.cards.firstIndex(where: { $0.id == card.id }) {
                    var updated = card
                    updated.updatedAt = Date()
                    board.columns[colIdx].cards[cardIdx] = updated
                    return
                }
            }
        }
    }

    func deleteCard(_ cardId: UUID) {
        mutateActiveBoard { board in
            for (idx, _) in board.columns.enumerated() {
                board.columns[idx].cards.removeAll { $0.id == cardId }
            }
        }
        backing.flushSyncNow()
    }

    func moveCard(cardId: UUID, fromColumn: UUID, toColumn: UUID, toIndex: Int) {
        mutateActiveBoard { board in
            guard let fromIdx = board.columns.firstIndex(where: { $0.id == fromColumn }),
                  let toIdx = board.columns.firstIndex(where: { $0.id == toColumn }),
                  let cardIdx = board.columns[fromIdx].cards.firstIndex(where: { $0.id == cardId }) else {
                return
            }
            let card = board.columns[fromIdx].cards.remove(at: cardIdx)
            let insertAt: Int
            if fromIdx == toIdx, toIndex > cardIdx {
                insertAt = max(0, min(toIndex - 1, board.columns[toIdx].cards.count))
            } else {
                insertAt = max(0, min(toIndex, board.columns[toIdx].cards.count))
            }
            board.columns[toIdx].cards.insert(card, at: insertAt)
        }
    }

    // MARK: - Card visibility (hide / unhide)

    func hideCard(_ cardId: UUID) {
        mutateActiveBoard { board in
            if !board.hiddenCardIds.contains(cardId) {
                board.hiddenCardIds.append(cardId)
            }
        }
    }

    func unhideCard(_ cardId: UUID) {
        mutateActiveBoard { board in
            board.hiddenCardIds.removeAll { $0 == cardId }
        }
    }

    func unhideAllCards() {
        mutateActiveBoard { board in
            board.hiddenCardIds.removeAll()
        }
    }

    // MARK: - Column

    func addColumn(_ column: KanbanColumn) {
        mutateActiveBoard { board in
            board.columns.append(column)
        }
    }

    func renameColumn(_ id: UUID, name: String) {
        mutateActiveBoard { board in
            guard let idx = board.columns.firstIndex(where: { $0.id == id }) else { return }
            board.columns[idx].name = name
        }
    }

    func deleteColumn(_ id: UUID) {
        mutateActiveBoard { board in
            board.columns.removeAll { $0.id == id }
        }
        backing.flushSyncNow()
    }

    func reorderColumn(from: Int, to: Int) {
        mutateActiveBoard { board in
            guard from != to,
                  from >= 0, from < board.columns.count,
                  to >= 0, to <= board.columns.count else { return }
            let item = board.columns.remove(at: from)
            board.columns.insert(item, at: min(to, board.columns.count))
        }
    }

    func setColumnColor(_ id: UUID, colorHex: String?) {
        mutateActiveBoard { board in
            guard let idx = board.columns.firstIndex(where: { $0.id == id }) else { return }
            board.columns[idx].colorHex = colorHex
        }
    }

    // MARK: - Label

    func addLabel(_ label: KanbanLabel) {
        mutateActiveBoard { board in
            board.labels.append(label)
        }
    }

    func updateLabel(_ label: KanbanLabel) {
        mutateActiveBoard { board in
            guard let idx = board.labels.firstIndex(where: { $0.id == label.id }) else { return }
            board.labels[idx] = label
        }
    }

    func deleteLabel(_ id: UUID) {
        mutateActiveBoard { board in
            board.labels.removeAll { $0.id == id }
            for (colIdx, _) in board.columns.enumerated() {
                for (cardIdx, _) in board.columns[colIdx].cards.enumerated() {
                    board.columns[colIdx].cards[cardIdx].labelIds.removeAll { $0 == id }
                }
            }
        }
        backing.flushSyncNow()
    }

    // MARK: - Helpers

    private func mutateActiveBoard(_ block: (inout KanbanBoard) -> Void) {
        backing.update { data in
            guard let activeId = data.activeBoardId,
                  let idx = data.boards.firstIndex(where: { $0.id == activeId }) else {
                return
            }
            block(&data.boards[idx])
            data.boards[idx].updatedAt = Date()
        }
    }
}
