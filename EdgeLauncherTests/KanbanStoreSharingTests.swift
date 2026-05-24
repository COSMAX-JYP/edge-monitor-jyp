import XCTest
@testable import EdgeLauncher

@MainActor
final class KanbanStoreSharingTests: XCTestCase {

    private func makeStore() -> KanbanStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kanban-share-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return KanbanStore(url: dir.appendingPathComponent("kanban.json"))
    }

    func test_addingCardInOneVM_appearsInOtherVM() {
        let store = makeStore()
        let a = KanbanViewModel(store: store)
        let b = KanbanViewModel(store: store)

        let column = a.activeBoard!.columns.first!
        a.startNewCard(in: column.id)
        var c = a.editingCard!
        c.title = "Shared"
        a.saveEditing(c)

        XCTAssertEqual(b.activeBoard!.columns.first!.cards.map(\.title), ["Shared"])
    }

    func test_searchQuery_isIndependent() {
        let store = makeStore()
        let a = KanbanViewModel(store: store)
        let b = KanbanViewModel(store: store)
        a.searchQuery = "foo"
        XCTAssertEqual(a.searchQuery, "foo")
        XCTAssertEqual(b.searchQuery, "")
    }

    func test_editingCardState_isIndependent() {
        let store = makeStore()
        let a = KanbanViewModel(store: store)
        let b = KanbanViewModel(store: store)
        let column = a.activeBoard!.columns.first!
        a.startNewCard(in: column.id)
        XCTAssertNotNil(a.editingCard)
        XCTAssertNil(b.editingCard)
    }
}
