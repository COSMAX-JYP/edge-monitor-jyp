import XCTest
import SwiftUI
@testable import EdgeLauncher

final class ModuleRegistryReorderTests: XCTestCase {
    func test_reorder_moves_module() {
        let reg = makeRegistry()
        reg.register(AnyEdgeModule(StubReorderModule(id: "a")))
        reg.register(AnyEdgeModule(StubReorderModule(id: "b")))
        reg.register(AnyEdgeModule(StubReorderModule(id: "c")))
        reg.reorder(from: 0, to: 2)
        XCTAssertEqual(reg.modules.map(\.id), ["b", "c", "a"])
    }

    func test_hide_filters_visible_modules() {
        let reg = makeRegistry()
        reg.register(AnyEdgeModule(StubReorderModule(id: "a")))
        reg.register(AnyEdgeModule(StubReorderModule(id: "b")))
        reg.setVisible("b", visible: false)
        XCTAssertEqual(reg.visibleModules.map(\.id), ["a"])
        XCTAssertTrue(reg.hiddenIDs.contains("b"))
    }

    private func makeRegistry() -> ModuleRegistry {
        let suite = UserDefaults(suiteName: "registry-test-\(UUID().uuidString)")!
        suite.removePersistentDomain(forName: suite.dictionaryRepresentation().keys.first ?? "")
        return ModuleRegistry(defaults: suite)
    }
}

private struct StubReorderModule: EdgeModule {
    let id: String
    let title: String
    let iconName = "circle"
    let supportsFullscreen = false

    init(id: String) { self.id = id; self.title = id.uppercased() }

    var view: some View { Text(title) }
}
