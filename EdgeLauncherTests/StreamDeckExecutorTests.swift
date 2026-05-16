import XCTest
@testable import EdgeLauncher

@MainActor
final class StreamDeckExecutorTests: XCTestCase {

    func test_noAction_throwsNoAction() async {
        do {
            try await ActionExecutor.run(.none)
            XCTFail("expected throw")
        } catch let err as ActionExecutorError {
            if case .noAction = err {} else { XCTFail("wrong error \(err)") }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func test_launchApp_emptyBundleId_throws() async {
        do {
            try await ActionExecutor.run(.launchApp(bundleId: ""))
            XCTFail("expected throw")
        } catch let err as ActionExecutorError {
            if case .invalidInput = err {} else { XCTFail("wrong error \(err)") }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func test_launchApp_unknownBundleId_throws() async {
        do {
            try await ActionExecutor.run(.launchApp(bundleId: "com.nonexistent.app.xyz123"))
            XCTFail("expected throw")
        } catch let err as ActionExecutorError {
            if case .appNotFound = err {} else { XCTFail("wrong error \(err)") }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func test_openURL_invalidString_throws() async {
        do {
            try await ActionExecutor.run(.openURL(url: ""))
            XCTFail("expected throw")
        } catch let err as ActionExecutorError {
            if case .invalidInput = err {} else { XCTFail("wrong error \(err)") }
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func test_keystrokeSender_keycode_maps_basicKeys() {
        XCTAssertNotNil(KeystrokeSender.keycode(for: "a"))
        XCTAssertNotNil(KeystrokeSender.keycode(for: "Return"))
        XCTAssertNotNil(KeystrokeSender.keycode(for: "space"))
        XCTAssertNotNil(KeystrokeSender.keycode(for: "f5"))
        XCTAssertNil(KeystrokeSender.keycode(for: "unknownkey"))
    }

    func test_keystrokeModifiers_symbol_orderedICOC() {
        let all: KeystrokeModifiers = [.command, .option, .shift, .control]
        XCTAssertEqual(all.symbol, "⌃⌥⇧⌘")
    }
}
