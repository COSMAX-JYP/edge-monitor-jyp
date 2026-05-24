import XCTest
@testable import EdgeLauncher

@MainActor
final class KanbanSlidePanelControllerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "slidepanel-ctrl-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    private func makeStore() -> KanbanStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kanban-ctrl-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return KanbanStore(url: dir.appendingPathComponent("kanban.json"))
    }

    private func make() -> KanbanSlidePanelController {
        KanbanSlidePanelController(
            store: makeStore(),
            settings: KanbanSlidePanelSettings(defaults: defaults)
        )
    }

    func test_initialHidden() {
        let c = make()
        XCTAssertEqual(c.state, .hidden)
    }

    func test_show_thenHide_withAnimationsDisabled() {
        let c = make()
        c.animationsEnabled = false
        c.show()
        XCTAssertEqual(c.state, .shown)
        c.hide()
        XCTAssertEqual(c.state, .hidden)
    }

    func test_toggle_alternates() {
        let c = make()
        c.animationsEnabled = false
        c.toggle()
        XCTAssertEqual(c.state, .shown)
        c.toggle()
        XCTAssertEqual(c.state, .hidden)
    }

    func test_doubleShow_isIdempotent() {
        let c = make()
        c.animationsEnabled = false
        c.show(); c.show()
        XCTAssertEqual(c.state, .shown)
    }

    func test_pinPersists() {
        let s = KanbanSlidePanelSettings(defaults: defaults)
        let c = KanbanSlidePanelController(store: makeStore(), settings: s)
        c.setPinned(true)
        XCTAssertTrue(s.isPinned)
    }

    func test_animationTokenInvalidated_onCounterAction() async {
        let s = KanbanSlidePanelSettings(defaults: defaults)
        s.slideAnimationDuration = 0.10
        let c = KanbanSlidePanelController(store: makeStore(), settings: s)
        c.show()
        XCTAssertEqual(c.state, .animatingIn)
        c.hide()
        XCTAssertEqual(c.state, .animatingOut)
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(c.state, .hidden)
    }

    func test_computeTargetFrame_rightEdgeAnchored() {
        let f = KanbanSlidePanelController.computeTargetFrame(
            screenFrame: NSRect(x: 0, y: 0, width: 2560, height: 1440),
            panelWidth: 400,
            heightRatio: 0.92
        )
        XCTAssertEqual(f.maxX, 2560, accuracy: 0.5)
        XCTAssertEqual(f.width, 400, accuracy: 0.5)
    }

    func test_computeStartFrame_outsideRightEdge() {
        let f = KanbanSlidePanelController.computeStartFrame(
            screenFrame: NSRect(x: 0, y: 0, width: 2560, height: 1440),
            panelWidth: 400,
            heightRatio: 0.92
        )
        XCTAssertEqual(f.minX, 2560, accuracy: 0.5)
    }
}
