import XCTest
import Carbon.HIToolbox
@testable import EdgeLauncher

@MainActor
final class KanbanSlidePanelSettingsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "slidepanel-test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    func test_defaults() {
        let s = KanbanSlidePanelSettings(defaults: defaults)
        XCTAssertEqual(s.hotKeyCode, KanbanSlidePanelSettings.defaultHotKeyCode)
        XCTAssertEqual(s.hotKeyModifiers, KanbanSlidePanelSettings.defaultHotKeyModifiers)
        XCTAssertEqual(s.panelWidth, 420, accuracy: 0.01)
        XCTAssertEqual(s.targetDisplayPolicy, .mouseLocation)
        XCTAssertTrue(s.autoHideOnBlur)
        XCTAssertTrue(s.autoHideOnEscape)
        XCTAssertFalse(s.isPinned)
        XCTAssertEqual(s.slideAnimationDuration, 0.20, accuracy: 0.01)
    }

    func test_persistRoundtrip() {
        let a = KanbanSlidePanelSettings(defaults: defaults)
        a.panelWidth = 600
        a.autoHideOnBlur = false
        a.isPinned = true
        a.slideAnimationDuration = 0.30
        a.targetDisplayPolicy = .specific(displayUUID: "ABC-123")

        let b = KanbanSlidePanelSettings(defaults: defaults)
        XCTAssertEqual(b.panelWidth, 600, accuracy: 0.01)
        XCTAssertFalse(b.autoHideOnBlur)
        XCTAssertTrue(b.isPinned)
        XCTAssertEqual(b.slideAnimationDuration, 0.30, accuracy: 0.01)
        XCTAssertEqual(b.targetDisplayPolicy, .specific(displayUUID: "ABC-123"))
    }

    func test_panelWidthClamps() {
        let s = KanbanSlidePanelSettings(defaults: defaults)
        s.panelWidth = 100
        XCTAssertEqual(s.panelWidth, KanbanSlidePanelSettings.minPanelWidth, accuracy: 0.01)
        s.panelWidth = 9999
        XCTAssertEqual(s.panelWidth, KanbanSlidePanelSettings.maxPanelWidth, accuracy: 0.01)
    }

    func test_targetDisplayPolicy_mainAndMouse() {
        let s = KanbanSlidePanelSettings(defaults: defaults)
        s.targetDisplayPolicy = .mainDisplay
        XCTAssertEqual(s.targetDisplayPolicy, .mainDisplay)
        s.targetDisplayPolicy = .mouseLocation
        XCTAssertEqual(s.targetDisplayPolicy, .mouseLocation)
    }
}
