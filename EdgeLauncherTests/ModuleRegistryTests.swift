import XCTest
@testable import EdgeLauncher

final class ModuleRegistryTests: XCTestCase {
    func test_register_and_lookup() {
        let reg = ModuleRegistry()
        let stub = AnyEdgeModule(StubModule(id: "stub", title: "Stub", iconName: "circle"))
        reg.register(stub)
        XCTAssertEqual(reg.modules.count, 1)
        XCTAssertEqual(reg.module(id: "stub")?.title, "Stub")
    }

    func test_duplicate_id_replaces_previous() {
        let reg = ModuleRegistry()
        reg.register(AnyEdgeModule(StubModule(id: "stub", title: "A", iconName: "circle")))
        reg.register(AnyEdgeModule(StubModule(id: "stub", title: "B", iconName: "circle")))
        XCTAssertEqual(reg.modules.count, 1)
        XCTAssertEqual(reg.module(id: "stub")?.title, "B")
    }

    func test_modules_preserve_registration_order() {
        let reg = ModuleRegistry()
        reg.register(AnyEdgeModule(StubModule(id: "a", title: "A", iconName: "circle")))
        reg.register(AnyEdgeModule(StubModule(id: "b", title: "B", iconName: "circle")))
        XCTAssertEqual(reg.modules.map(\.id), ["a", "b"])
    }
}
