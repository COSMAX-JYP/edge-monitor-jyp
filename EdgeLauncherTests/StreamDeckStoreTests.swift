import XCTest
@testable import EdgeLauncher

@MainActor
final class StreamDeckStoreTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("streamdeck-test-\(UUID().uuidString)")
            .appendingPathComponent("streamdeck.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
        try await super.tearDown()
    }

    func test_initial_seedsDefaultPage() {
        let store = StreamDeckStore(url: tempURL, seedDefaultApps: false)
        XCTAssertEqual(store.data.pages.count, 1)
        XCTAssertNotNil(store.activePage)
        XCTAssertEqual(store.activePage?.gridSize.rows, 4)
        XCTAssertEqual(store.activePage?.gridSize.cols, 12)
    }

    func test_initial_seedsRequestedAppButtons() {
        let store = StreamDeckStore(url: tempURL)
        let labels = Set(store.activePage?.buttons.map(\.label) ?? [])
        XCTAssertTrue(labels.isSuperset(of: ["Warp", "Teams", "Outlook", "Obsidian", "DBeaver", "CotEditor", "GPT", "Claude", "메모", "설정", "Chrome", "카카오톡", "Excel", "KMS", "LOG-JYP"]))
    }

    func test_initial_seedsRequestedLinkButtons() {
        let store = StreamDeckStore(url: tempURL)
        let labels = Set(store.activePage?.buttons.map(\.label) ?? [])
        XCTAssertTrue(labels.isSuperset(of: ["PI혁신부문", "EAI_Datahub", "비상연락망", "연차현황"]))
    }

    func test_upsertButton_inserts() {
        let store = StreamDeckStore(url: tempURL, seedDefaultApps: false)
        let button = StreamDeckButton(
            position: GridPosition(row: 0, col: 0),
            label: "Test",
            action: .launchApp(bundleId: "com.apple.Notes")
        )
        store.upsertButton(button)
        XCTAssertEqual(store.activePage?.buttons.count, 1)
        XCTAssertEqual(store.activePage?.buttons.first?.label, "Test")
    }

    func test_upsertButton_updatesAtSamePosition() {
        let store = StreamDeckStore(url: tempURL, seedDefaultApps: false)
        let pos = GridPosition(row: 0, col: 0)
        let first = StreamDeckButton(position: pos, label: "A", action: .openURL(url: "https://a.com"))
        store.upsertButton(first)
        let second = StreamDeckButton(position: pos, label: "B", action: .openURL(url: "https://b.com"))
        store.upsertButton(second)
        XCTAssertEqual(store.activePage?.buttons.count, 1)
        XCTAssertEqual(store.activePage?.buttons.first?.label, "B")
    }

    func test_deleteButton_atPosition() {
        let store = StreamDeckStore(url: tempURL, seedDefaultApps: false)
        let pos = GridPosition(row: 1, col: 2)
        store.upsertButton(StreamDeckButton(position: pos, label: "X"))
        store.deleteButton(at: pos)
        XCTAssertTrue(store.activePage?.buttons.isEmpty ?? false)
    }

    func test_moveButton_swapsOccupiedPosition() {
        let store = StreamDeckStore(url: tempURL, seedDefaultApps: false)
        let first = StreamDeckButton(position: GridPosition(row: 0, col: 0), label: "A")
        let second = StreamDeckButton(position: GridPosition(row: 0, col: 1), label: "B")
        store.upsertButton(first)
        store.upsertButton(second)

        store.moveButton(id: first.id, to: GridPosition(row: 0, col: 1))

        XCTAssertEqual(store.activePage?.buttons.first { $0.id == first.id }?.position, GridPosition(row: 0, col: 1))
        XCTAssertEqual(store.activePage?.buttons.first { $0.id == second.id }?.position, GridPosition(row: 0, col: 0))
    }

    func test_persistence_roundtrip() async throws {
        let store = StreamDeckStore(url: tempURL, seedDefaultApps: false)
        let button = StreamDeckButton(
            position: GridPosition(row: 2, col: 5),
            label: "Persist",
            action: .keystroke(modifiers: [.command, .shift], key: "p")
        )
        store.upsertButton(button)
        try await store.flush()

        let reloaded = StreamDeckStore(url: tempURL, seedDefaultApps: false)
        let restored = reloaded.activePage?.buttons.first
        XCTAssertEqual(restored?.label, "Persist")
        if case .keystroke(let mods, let key)? = restored?.action {
            XCTAssertTrue(mods.contains(.command))
            XCTAssertTrue(mods.contains(.shift))
            XCTAssertEqual(key, "p")
        } else {
            XCTFail("expected keystroke action")
        }
    }
}
