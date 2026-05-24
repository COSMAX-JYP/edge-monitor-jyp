import XCTest
import Carbon.HIToolbox
@testable import EdgeLauncher

@MainActor
final class KanbanSlidePanelHotKeyTests: XCTestCase {

    func test_bind_storesCurrentCombination() throws {
        let fake = FakeHotKeyRegistrar()
        let hk = KanbanSlidePanelHotKey(registrar: fake)
        try hk.bind(keyCode: kVK_ANSI_K, modifiers: UInt32(cmdKey | shiftKey)) {}
        XCTAssertEqual(hk.currentKeyCode, kVK_ANSI_K)
        XCTAssertEqual(hk.currentModifiers, UInt32(cmdKey | shiftKey))
        XCTAssertEqual(fake.activeRegistrations.count, 1)
    }

    func test_rebind_replacesPrevious() throws {
        let fake = FakeHotKeyRegistrar()
        let hk = KanbanSlidePanelHotKey(registrar: fake)
        try hk.bind(keyCode: kVK_ANSI_K, modifiers: UInt32(cmdKey | shiftKey)) {}
        try hk.bind(keyCode: kVK_ANSI_J, modifiers: UInt32(cmdKey | optionKey)) {}
        XCTAssertEqual(hk.currentKeyCode, kVK_ANSI_J)
        XCTAssertEqual(fake.activeRegistrations.count, 1)
    }

    func test_unbind_clearsState() throws {
        let fake = FakeHotKeyRegistrar()
        let hk = KanbanSlidePanelHotKey(registrar: fake)
        try hk.bind(keyCode: kVK_ANSI_K, modifiers: 0) {}
        hk.unbind()
        XCTAssertNil(hk.currentKeyCode)
        XCTAssertEqual(fake.activeRegistrations.count, 0)
    }

    func test_bind_failurePreservesPreviousState() throws {
        let fake = FakeHotKeyRegistrar()
        let hk = KanbanSlidePanelHotKey(registrar: fake)
        try hk.bind(keyCode: kVK_ANSI_K, modifiers: 0) {}
        fake.shouldFailNextRegister = .registrationFailed(status: -100)
        XCTAssertThrowsError(try hk.bind(keyCode: kVK_ANSI_J, modifiers: 0) {})
        // 실패 시 기존 바인딩 유지 보장
        XCTAssertEqual(hk.currentKeyCode, kVK_ANSI_K)
    }

    func test_callback_firesViaRegistrar() throws {
        let fake = FakeHotKeyRegistrar()
        let hk = KanbanSlidePanelHotKey(registrar: fake)
        var count = 0
        try hk.bind(keyCode: kVK_ANSI_K, modifiers: 0) { count += 1 }
        fake.trigger(token: fake.activeRegistrations.first!.token)
        XCTAssertEqual(count, 1)
    }

    func test_sameComboRebind_unregistersFirst() throws {
        let fake = FakeHotKeyRegistrar()
        let hk = KanbanSlidePanelHotKey(registrar: fake)
        try hk.bind(keyCode: kVK_ANSI_K, modifiers: UInt32(cmdKey | shiftKey)) {}
        let firstToken = fake.activeRegistrations.first!.token
        try hk.bind(keyCode: kVK_ANSI_K, modifiers: UInt32(cmdKey | shiftKey)) {}
        XCTAssertEqual(fake.activeRegistrations.count, 1)
        XCTAssertNotEqual(fake.activeRegistrations.first!.token, firstToken,
                          "same combo rebind must produce a fresh token")
    }

    func test_rebindExisting_callsBindAgain() throws {
        let fake = FakeHotKeyRegistrar()
        let hk = KanbanSlidePanelHotKey(registrar: fake)
        var fired = 0
        try hk.bind(keyCode: kVK_ANSI_K, modifiers: 0) { fired += 1 }
        let firstToken = fake.activeRegistrations.first!.token
        try hk.rebindExisting { fired += 1 }
        XCTAssertNotEqual(fake.activeRegistrations.first!.token, firstToken)
        XCTAssertEqual(hk.currentKeyCode, kVK_ANSI_K)
    }
}
