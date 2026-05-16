import XCTest
@testable import EdgeLauncher

@MainActor
final class KanbanViewModelTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kanban-vm-test-\(UUID().uuidString)")
            .appendingPathComponent("kanban.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
        try await super.tearDown()
    }

    func test_startNewCard_setsEditing() {
        let store = KanbanStore(url: tempURL)
        let vm = KanbanViewModel(store: store)
        let column = vm.activeBoard!.columns.first!
        vm.startNewCard(in: column.id)
        XCTAssertNotNil(vm.editingCard)
        XCTAssertEqual(vm.editingTargetColumnId, column.id)
    }

    func test_saveEditing_addsCardForNewFlow() {
        let store = KanbanStore(url: tempURL)
        let vm = KanbanViewModel(store: store)
        let column = vm.activeBoard!.columns.first!
        vm.startNewCard(in: column.id)
        var card = vm.editingCard!
        card.title = "Created"
        vm.saveEditing(card)
        XCTAssertNil(vm.editingCard)
        XCTAssertEqual(vm.activeBoard!.columns.first!.cards.first?.title, "Created")
    }

    func test_saveEditing_updatesExistingCard() {
        let store = KanbanStore(url: tempURL)
        let vm = KanbanViewModel(store: store)
        let column = vm.activeBoard!.columns.first!
        let card = KanbanCard(title: "Old")
        store.addCard(card, to: column.id)
        vm.editCard(card)
        var updated = card
        updated.title = "New"
        vm.saveEditing(updated)
        XCTAssertEqual(vm.activeBoard!.columns.first!.cards.first?.title, "New")
    }

    func test_requestDelete_setsPending() {
        let store = KanbanStore(url: tempURL)
        let vm = KanbanViewModel(store: store)
        let column = vm.activeBoard!.columns.first!
        let card = KanbanCard(title: "Doomed")
        store.addCard(card, to: column.id)
        vm.requestDelete(card)
        XCTAssertEqual(vm.pendingDeleteCard?.id, card.id)
    }

    func test_confirmDelete_removesCard() {
        let store = KanbanStore(url: tempURL)
        let vm = KanbanViewModel(store: store)
        let column = vm.activeBoard!.columns.first!
        let card = KanbanCard(title: "Doomed")
        store.addCard(card, to: column.id)
        vm.requestDelete(card)
        vm.confirmDelete()
        XCTAssertNil(vm.pendingDeleteCard)
        XCTAssertTrue(vm.activeBoard!.columns.first!.cards.isEmpty)
    }

    func test_handleDrop_movesCard() {
        let store = KanbanStore(url: tempURL)
        let vm = KanbanViewModel(store: store)
        let board = vm.activeBoard!
        let from = board.columns[0]
        let to = board.columns[1]
        let card = KanbanCard(title: "Moving")
        store.addCard(card, to: from.id)
        let ref = KanbanCardRef(cardId: card.id, boardId: board.id, sourceColumnId: from.id)
        let consumed = vm.handleDrop(ref: ref, toColumn: to.id, toIndex: 0)
        XCTAssertTrue(consumed)
        XCTAssertTrue(vm.activeBoard!.columns.first { $0.id == from.id }!.cards.isEmpty)
        XCTAssertEqual(vm.activeBoard!.columns.first { $0.id == to.id }!.cards.first?.title, "Moving")
    }

    func test_handleDrop_rejectsWrongBoard() {
        let store = KanbanStore(url: tempURL)
        let vm = KanbanViewModel(store: store)
        let board = vm.activeBoard!
        let from = board.columns[0]
        let to = board.columns[1]
        let card = KanbanCard(title: "X")
        store.addCard(card, to: from.id)
        let ref = KanbanCardRef(cardId: card.id, boardId: UUID(), sourceColumnId: from.id)
        XCTAssertFalse(vm.handleDrop(ref: ref, toColumn: to.id, toIndex: 0))
    }

    func test_search_filtersByTitle() {
        let store = KanbanStore(url: tempURL)
        let vm = KanbanViewModel(store: store)
        let column = vm.activeBoard!.columns.first!
        store.addCard(KanbanCard(title: "Hello"), to: column.id)
        store.addCard(KanbanCard(title: "World"), to: column.id)
        vm.searchQuery = "hell"
        let cards = vm.visibleColumns.flatMap { $0.cards }
        XCTAssertEqual(cards.map(\.title), ["Hello"])
    }
}
