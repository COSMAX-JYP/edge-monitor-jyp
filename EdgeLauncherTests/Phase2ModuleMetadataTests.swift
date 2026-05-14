import XCTest
@testable import EdgeLauncher

final class Phase2ModuleMetadataTests: XCTestCase {
    func test_system_monitor_module() {
        let m = SystemMonitorModule()
        XCTAssertEqual(m.id, "system-monitor")
        XCTAssertEqual(m.title, "Monitor")
        XCTAssertEqual(m.iconName, "cpu")
        XCTAssertFalse(m.supportsFullscreen)
    }

    func test_widget_dashboard_module() {
        let m = WidgetDashboardModule()
        XCTAssertEqual(m.id, "widgets")
        XCTAssertEqual(m.title, "Widgets")
        XCTAssertEqual(m.iconName, "rectangle.grid.2x2")
        XCTAssertFalse(m.supportsFullscreen)
    }

    func test_messenger_module() {
        let m = MessengerModule()
        XCTAssertEqual(m.id, "messenger")
        XCTAssertEqual(m.title, "Discord")
        XCTAssertEqual(m.iconName, "bubble.left.and.bubble.right.fill")
        XCTAssertTrue(m.supportsFullscreen)
    }

    func test_launcher_module() {
        let m = LauncherModule()
        XCTAssertEqual(m.id, "launcher")
        XCTAssertEqual(m.title, "Launcher")
        XCTAssertEqual(m.iconName, "square.grid.3x3.fill")
        XCTAssertFalse(m.supportsFullscreen)
    }
}
