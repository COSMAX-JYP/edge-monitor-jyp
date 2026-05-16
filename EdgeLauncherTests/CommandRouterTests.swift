import XCTest
@testable import EdgeLauncher

@MainActor
final class CommandRouterTests: XCTestCase {

    private final class StubHandler: ModuleCommandHandler {
        var received: [ModuleCommand] = []
        var responses: [ModuleCommand: Bool] = [:]

        func handle(_ command: ModuleCommand) -> Bool {
            received.append(command)
            return responses[command] ?? true
        }
    }

    func test_dispatch_routesToActiveHandler() {
        let router = CommandRouter()
        let handler = StubHandler()
        router.register(handler, for: "moduleA")
        router.setActive("moduleA")

        let consumed = router.dispatch(.newItem)

        XCTAssertTrue(consumed)
        XCTAssertEqual(handler.received, [.newItem])
    }

    func test_dispatch_skipsInactiveHandler() {
        let router = CommandRouter()
        let active = StubHandler()
        let other = StubHandler()
        router.register(active, for: "active")
        router.register(other, for: "other")
        router.setActive("active")

        _ = router.dispatch(.refresh)

        XCTAssertEqual(active.received, [.refresh])
        XCTAssertEqual(other.received, [])
    }

    func test_dispatch_fallsBackToGlobalDefault_whenHandlerDeclines() {
        let router = CommandRouter()
        let handler = StubHandler()
        handler.responses[.slot1] = false
        router.register(handler, for: "moduleA")
        router.setActive("moduleA")

        var fallbackCalled = false
        router.setGlobalDefault(.slot1) { fallbackCalled = true }

        let consumed = router.dispatch(.slot1)

        XCTAssertTrue(consumed)
        XCTAssertTrue(fallbackCalled)
    }

    func test_dispatch_returnsFalse_whenNoHandlerAndNoDefault() {
        let router = CommandRouter()
        let consumed = router.dispatch(.newItem)
        XCTAssertFalse(consumed)
    }

    func test_dispatch_fallsBackToGlobalDefault_whenNoActiveModule() {
        let router = CommandRouter()
        var fired = false
        router.setGlobalDefault(.refresh) { fired = true }

        let consumed = router.dispatch(.refresh)

        XCTAssertTrue(consumed)
        XCTAssertTrue(fired)
    }

    func test_unregister_removesHandler() {
        let router = CommandRouter()
        let handler = StubHandler()
        router.register(handler, for: "moduleA")
        router.setActive("moduleA")
        router.unregister(moduleId: "moduleA")

        let consumed = router.dispatch(.newItem)

        XCTAssertFalse(consumed)
        XCTAssertEqual(handler.received, [])
    }

    func test_weakReference_doesNotRetainHandler() {
        let router = CommandRouter()
        weak var weakHandler: StubHandler?
        autoreleasepool {
            let handler = StubHandler()
            weakHandler = handler
            router.register(handler, for: "moduleA")
        }
        XCTAssertNil(weakHandler, "router must hold handler weakly")
    }

    func test_slot_helper() {
        XCTAssertEqual(ModuleCommand.slot(at: 0), .slot1)
        XCTAssertEqual(ModuleCommand.slot(at: 8), .slot9)
        XCTAssertNil(ModuleCommand.slot(at: 9))
        XCTAssertNil(ModuleCommand.slot(at: -1))
    }
}
