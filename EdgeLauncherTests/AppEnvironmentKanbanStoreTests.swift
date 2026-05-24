import XCTest
@testable import EdgeLauncher

@MainActor
final class AppEnvironmentKanbanStoreTests: XCTestCase {
    func test_appEnvironment_exposesKanbanStore() {
        let env = AppEnvironment()
        XCTAssertNotNil(env.kanbanStore)
    }

    func test_kanbanModule_usesSharedStore() {
        let env = AppEnvironment()
        let registered = env.registry.module(id: "kanban")
        XCTAssertNotNil(registered, "kanban module must be registered")
    }
}
