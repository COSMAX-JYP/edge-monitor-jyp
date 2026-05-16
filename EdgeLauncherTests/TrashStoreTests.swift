import XCTest
@testable import EdgeLauncher

@MainActor
final class TrashStoreTests: XCTestCase {

    private var directory: URL!

    override func setUp() async throws {
        try await super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("trash-test-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
        try await super.tearDown()
    }

    func test_push_persistsCard() {
        let store = TrashStore(directory: directory)
        let card = KanbanCard(title: "Doomed")
        let boardId = UUID()
        let columnId = UUID()
        store.push(card: card, boardId: boardId, columnId: columnId)
        XCTAssertEqual(store.list().count, 1)
    }

    func test_pop_returnsAndRemoves() {
        let store = TrashStore(directory: directory)
        let card = KanbanCard(title: "X")
        store.push(card: card, boardId: UUID(), columnId: UUID())
        let entry = store.pop(id: card.id)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.card.title, "X")
        XCTAssertEqual(store.list().count, 0)
    }

    func test_sweep_removesExpired() {
        let store = TrashStore(directory: directory, retentionDays: 30)
        let oldCard = KanbanCard(title: "Old")
        store.push(card: oldCard, boardId: UUID(), columnId: UUID())
        let future = Date().addingTimeInterval(86400 * 60)
        store.sweep(referenceDate: future)
        XCTAssertEqual(store.list().count, 0)
    }

    func test_sweep_keepsRecent() {
        let store = TrashStore(directory: directory, retentionDays: 30)
        let recent = KanbanCard(title: "Recent")
        store.push(card: recent, boardId: UUID(), columnId: UUID())
        store.sweep(referenceDate: Date().addingTimeInterval(86400 * 3))
        XCTAssertEqual(store.list().count, 1)
    }
}
