import XCTest
import Carbon.HIToolbox
@testable import EdgeLauncher

@MainActor
final class CarbonHotKeyRegistrarTests: XCTestCase {
    func test_shouldDispatch_acceptsOwnSignatureAndKnownId() {
        let hkID = EventHotKeyID(signature: CarbonHotKeyRegistrar.appSignature, id: 42)
        XCTAssertTrue(CarbonHotKeyRegistrar.shouldDispatch(hkID, knownIds: [42]))
    }

    func test_shouldDispatch_rejectsForeignSignature() {
        let hkID = EventHotKeyID(signature: OSType(0xDEADBEEF), id: 42)
        XCTAssertFalse(CarbonHotKeyRegistrar.shouldDispatch(hkID, knownIds: [42]))
    }

    func test_shouldDispatch_rejectsUnknownId() {
        let hkID = EventHotKeyID(signature: CarbonHotKeyRegistrar.appSignature, id: 99)
        XCTAssertFalse(CarbonHotKeyRegistrar.shouldDispatch(hkID, knownIds: [1, 2, 3]))
    }
}
