import XCTest
@testable import EdgeLauncher

@MainActor
final class KanbanStoreTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kanban-test-\(UUID().uuidString)")
            .appendingPathComponent("kanban.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
        try await super.tearDown()
    }

    func test_initial_seedsDefaultBoard() {
        let store = KanbanStore(url: tempURL)
        XCTAssertEqual(store.data.boards.count, 1)
        XCTAssertNotNil(store.activeBoard)
        XCTAssertEqual(store.activeBoard?.columns.count, 5)
    }

    func test_addCard_appendsToColumn() {
        let store = KanbanStore(url: tempURL)
        let board = store.activeBoard!
        let column = board.columns.first!
        let card = KanbanCard(title: "Task A")

        store.addCard(card, to: column.id)
        let updated = store.activeBoard!.columns.first { $0.id == column.id }!
        XCTAssertEqual(updated.cards.count, 1)
        XCTAssertEqual(updated.cards.first?.title, "Task A")
    }

    func test_updateCard_modifiesExisting() {
        let store = KanbanStore(url: tempURL)
        let column = store.activeBoard!.columns.first!
        var card = KanbanCard(title: "Original")
        store.addCard(card, to: column.id)
        card.title = "Updated"
        store.updateCard(card)
        let result = store.activeBoard!.columns.first!.cards.first
        XCTAssertEqual(result?.title, "Updated")
    }

    func test_deleteCard_removesAcrossColumns() {
        let store = KanbanStore(url: tempURL)
        let column = store.activeBoard!.columns.first!
        let card = KanbanCard(title: "Doomed")
        store.addCard(card, to: column.id)
        store.deleteCard(card.id)
        let result = store.activeBoard!.columns.first!.cards
        XCTAssertTrue(result.isEmpty)
    }

    func test_moveCard_acrossColumns() {
        let store = KanbanStore(url: tempURL)
        let board = store.activeBoard!
        let from = board.columns[0]
        let to = board.columns[1]
        let card = KanbanCard(title: "Mover")
        store.addCard(card, to: from.id)
        store.moveCard(cardId: card.id, fromColumn: from.id, toColumn: to.id, toIndex: 0)
        let fromColumn = store.activeBoard!.columns.first { $0.id == from.id }!
        let toColumn = store.activeBoard!.columns.first { $0.id == to.id }!
        XCTAssertTrue(fromColumn.cards.isEmpty)
        XCTAssertEqual(toColumn.cards.count, 1)
    }

    func test_moveCard_reorderWithinColumn() {
        let store = KanbanStore(url: tempURL)
        let column = store.activeBoard!.columns.first!
        let a = KanbanCard(title: "A")
        let b = KanbanCard(title: "B")
        let c = KanbanCard(title: "C")
        store.addCard(a, to: column.id)
        store.addCard(b, to: column.id)
        store.addCard(c, to: column.id)

        store.moveCard(cardId: a.id, fromColumn: column.id, toColumn: column.id, toIndex: 3)
        let updated = store.activeBoard!.columns.first!.cards.map(\.title)
        XCTAssertEqual(updated, ["B", "C", "A"])
    }

    func test_addColumn_appends() {
        let store = KanbanStore(url: tempURL)
        let initial = store.activeBoard!.columns.count
        store.addColumn(KanbanColumn(name: "New"))
        XCTAssertEqual(store.activeBoard!.columns.count, initial + 1)
        XCTAssertEqual(store.activeBoard!.columns.last?.name, "New")
    }

    func test_deleteColumn_removes() {
        let store = KanbanStore(url: tempURL)
        let column = store.activeBoard!.columns.first!
        store.deleteColumn(column.id)
        XCTAssertNil(store.activeBoard!.columns.first { $0.id == column.id })
    }

    func test_addBoard_setsActive() {
        let store = KanbanStore(url: tempURL)
        let board = KanbanBoard(name: "Second")
        store.addBoard(board)
        XCTAssertEqual(store.activeBoard?.id, board.id)
    }

    func test_persistence_roundtrip() async throws {
        let store = KanbanStore(url: tempURL)
        let column = store.activeBoard!.columns.first!
        let card = KanbanCard(title: "Persisted")
        store.addCard(card, to: column.id)
        try await store.flush()

        let reloaded = KanbanStore(url: tempURL)
        let result = reloaded.activeBoard!.columns.first!.cards.first
        XCTAssertEqual(result?.title, "Persisted")
    }
}
