import XCTest
@testable import EdgeLauncher

@MainActor
final class ActionStatsStoreTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("stats-test-\(UUID().uuidString)")
            .appendingPathComponent("streamdeck-stats.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
        try await super.tearDown()
    }

    func test_recordTap_incrementsCount() {
        let store = ActionStatsStore(url: tempURL)
        let id = UUID()
        store.recordTap(id)
        store.recordTap(id)
        let entry = store.entry(for: id)
        XCTAssertEqual(entry.tapCount, 2)
        XCTAssertNotNil(entry.lastTappedAt)
    }

    func test_recordSuccess_tracksDuration() {
        let store = ActionStatsStore(url: tempURL)
        let id = UUID()
        store.recordSuccess(id, duration: 1.5)
        store.recordSuccess(id, duration: 0.5)
        let entry = store.entry(for: id)
        XCTAssertEqual(entry.successCount, 2)
        XCTAssertEqual(entry.totalDurationSeconds, 2.0, accuracy: 0.001)
        XCTAssertEqual(entry.averageDuration, 1.0, accuracy: 0.001)
    }

    func test_recordError_storesMessage() {
        let store = ActionStatsStore(url: tempURL)
        let id = UUID()
        store.recordError(id, message: "fail")
        let entry = store.entry(for: id)
        XCTAssertEqual(entry.errorCount, 1)
        XCTAssertEqual(entry.lastError, "fail")
    }

    func test_successRate_calculates() {
        let store = ActionStatsStore(url: tempURL)
        let id = UUID()
        store.recordTap(id)
        store.recordTap(id)
        store.recordTap(id)
        store.recordSuccess(id, duration: 0.1)
        store.recordError(id, message: "x")
        let entry = store.entry(for: id)
        XCTAssertEqual(entry.successRate, 1.0/3.0, accuracy: 0.01)
    }

    func test_topUsed_sortsByTapCount() {
        let store = ActionStatsStore(url: tempURL)
        let a = UUID(), b = UUID(), c = UUID()
        store.recordTap(a)
        store.recordTap(b); store.recordTap(b); store.recordTap(b)
        store.recordTap(c); store.recordTap(c)
        let top = store.topUsed(limit: 5)
        XCTAssertEqual(top.map(\.tapCount), [3, 2, 1])
    }

    func test_reset_clearsAll() {
        let store = ActionStatsStore(url: tempURL)
        store.recordTap(UUID())
        store.reset()
        XCTAssertEqual(store.data.entries.count, 0)
    }
}
