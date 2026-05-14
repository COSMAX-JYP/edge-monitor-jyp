import XCTest
@testable import EdgeLauncher

final class TabRouterTests: XCTestCase {
    func test_initial_active_id_is_nil() {
        let suite = UserDefaults(suiteName: #function)!
        suite.removePersistentDomain(forName: #function)
        let router = TabRouter(defaults: suite)
        XCTAssertNil(router.activeID)
    }

    func test_activate_sets_id() {
        let suite = UserDefaults(suiteName: #function)!
        suite.removePersistentDomain(forName: #function)
        let router = TabRouter(defaults: suite)
        router.activate("youtube")
        XCTAssertEqual(router.activeID, "youtube")
    }

    func test_persisted_active_id_loads_from_defaults() {
        let suite = UserDefaults(suiteName: #function)!
        suite.removePersistentDomain(forName: #function)
        suite.set("youtube-music", forKey: "app.activeTab")
        let router = TabRouter(defaults: suite)
        XCTAssertEqual(router.activeID, "youtube-music")
    }
}
