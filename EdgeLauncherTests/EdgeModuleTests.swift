import XCTest
import SwiftUI
@testable import EdgeLauncher

final class EdgeModuleTests: XCTestCase {
    func test_module_has_required_metadata() {
        let mod = StubModule(id: "stub", title: "Stub", iconName: "circle")
        XCTAssertEqual(mod.id, "stub")
        XCTAssertEqual(mod.title, "Stub")
        XCTAssertEqual(mod.iconName, "circle")
    }
}

struct StubModule: EdgeModule {
    let id: String
    let title: String
    let iconName: String
    var supportsFullscreen: Bool { false }
    @ViewBuilder var view: some View { Text("stub") }
}
