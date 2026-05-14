import XCTest
@testable import EdgeLauncher

@MainActor
final class LauncherStoreTests: XCTestCase {
    func test_add_appends_new_entry() {
        let store = LauncherStore()
        let initialCount = store.entries.count
        let entry = LauncherEntry(name: "Temp", bundleURL: "/tmp/Temp-\(UUID().uuidString).app")
        store.entries.append(entry)
        XCTAssertEqual(store.entries.count, initialCount + 1)
    }

    func test_add_dedup_same_path() {
        let store = LauncherStore()
        let path = "/tmp/Dedup-\(UUID().uuidString).app"
        store.add(url: URL(fileURLWithPath: path))
        let after = store.entries.count
        store.add(url: URL(fileURLWithPath: path))
        XCTAssertEqual(store.entries.count, after)
    }

    func test_remove_drops_entry() {
        let store = LauncherStore()
        let entry = LauncherEntry(name: "Drop", bundleURL: "/tmp/Drop-\(UUID().uuidString).app")
        store.entries.append(entry)
        store.remove(entry)
        XCTAssertFalse(store.entries.contains(entry))
    }
}
