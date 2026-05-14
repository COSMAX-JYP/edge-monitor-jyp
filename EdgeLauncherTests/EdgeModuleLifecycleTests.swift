import XCTest
import SwiftUI
@testable import EdgeLauncher

final class EdgeModuleLifecycleTests: XCTestCase {
    func test_any_module_forwards_lifecycle() {
        let module = TrackingModule()
        let any = AnyEdgeModule(module)
        any.didBecomeActive()
        any.didResignActive()
        any.didBecomeActive()
        XCTAssertEqual(module.shared.becameActiveCount, 2)
        XCTAssertEqual(module.shared.resignedCount, 1)
    }
}

private struct TrackingModule: EdgeModule {
    let id = "tracker"
    let title = "Tracker"
    let iconName = "circle"
    let supportsFullscreen = false
    var view: some View { Text("tracker") }

    final class Shared {
        var becameActiveCount = 0
        var resignedCount = 0
    }
    let shared = Shared()

    func didBecomeActive() { shared.becameActiveCount += 1 }
    func didResignActive() { shared.resignedCount += 1 }
}
