import XCTest
import Carbon.HIToolbox
@testable import EdgeLauncher

@MainActor
final class FakeHotKeyRegistrarTests: XCTestCase {

    func test_register_returnsToken_andRecordsEntry() throws {
        let fake = FakeHotKeyRegistrar()
        var fired = 0
        let token = try fake.register(keyCode: kVK_ANSI_K, modifiers: UInt32(cmdKey | shiftKey)) { fired += 1 }
        XCTAssertEqual(fake.activeRegistrations.count, 1)
        fake.trigger(token: token)
        XCTAssertEqual(fired, 1)
    }

    func test_unregister_removesEntry() throws {
        let fake = FakeHotKeyRegistrar()
        let token = try fake.register(keyCode: kVK_ANSI_K, modifiers: 0) { }
        fake.unregister(token)
        XCTAssertEqual(fake.activeRegistrations.count, 0)
    }

    func test_register_canFail_whenConfigured() {
        let fake = FakeHotKeyRegistrar()
        fake.shouldFailNextRegister = .registrationFailed(status: -9870)
        XCTAssertThrowsError(try fake.register(keyCode: 0, modifiers: 0) { })
    }
}
