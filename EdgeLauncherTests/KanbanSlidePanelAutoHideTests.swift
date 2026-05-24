import XCTest
import AppKit
@testable import EdgeLauncher

@MainActor
final class KanbanSlidePanelAutoHideTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: "autohide-\(UUID().uuidString)")!
    }

    private func makeVM() -> KanbanViewModel {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kanban-ah-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return KanbanViewModel(store: KanbanStore(url: dir.appendingPathComponent("kanban.json")))
    }

    func test_suspend_whenPinned() {
        let s = KanbanSlidePanelSettings(defaults: defaults)
        s.isPinned = true
        let ah = KanbanSlidePanelAutoHide(viewModel: makeVM(), settings: s, panelFrameProvider: { .zero })
        XCTAssertTrue(ah.shouldSuspend())
    }

    func test_suspend_whenAutoHideOff() {
        let s = KanbanSlidePanelSettings(defaults: defaults)
        s.autoHideOnBlur = false
        let ah = KanbanSlidePanelAutoHide(viewModel: makeVM(), settings: s, panelFrameProvider: { .zero })
        XCTAssertTrue(ah.shouldSuspend())
    }

    func test_suspend_whenEditingCard() {
        let s = KanbanSlidePanelSettings(defaults: defaults)
        let vm = makeVM()
        let col = vm.activeBoard!.columns.first!
        vm.startNewCard(in: col.id)
        let ah = KanbanSlidePanelAutoHide(viewModel: vm, settings: s, panelFrameProvider: { .zero })
        XCTAssertTrue(ah.shouldSuspend())
    }

    func test_suspend_whenLabelManagerOpen() {
        let s = KanbanSlidePanelSettings(defaults: defaults)
        let vm = makeVM()
        vm.openLabelManager()
        let ah = KanbanSlidePanelAutoHide(viewModel: vm, settings: s, panelFrameProvider: { .zero })
        XCTAssertTrue(ah.shouldSuspend())
    }

    func test_clickInsidePanelFrame_doesNotTriggerHide() {
        let s = KanbanSlidePanelSettings(defaults: defaults)
        let frame = NSRect(x: 100, y: 100, width: 400, height: 800)
        var hideCalled = false
        let ah = KanbanSlidePanelAutoHide(viewModel: makeVM(), settings: s, panelFrameProvider: { frame })
        ah.onHideRequested = { hideCalled = true }
        ah.handleClick(at: NSPoint(x: 200, y: 400))
        XCTAssertFalse(hideCalled)
    }

    func test_clickOutsidePanelFrame_triggersHide() {
        let s = KanbanSlidePanelSettings(defaults: defaults)
        let frame = NSRect(x: 100, y: 100, width: 400, height: 800)
        var hideCalled = false
        let ah = KanbanSlidePanelAutoHide(viewModel: makeVM(), settings: s, panelFrameProvider: { frame })
        ah.onHideRequested = { hideCalled = true }
        ah.handleClick(at: NSPoint(x: 50, y: 50))
        XCTAssertTrue(hideCalled)
    }

    func test_clickOutsideDoesNotHide_whenSuspended() {
        let s = KanbanSlidePanelSettings(defaults: defaults)
        s.isPinned = true
        var hideCalled = false
        let ah = KanbanSlidePanelAutoHide(viewModel: makeVM(), settings: s, panelFrameProvider: { NSRect(x: 100, y: 100, width: 10, height: 10) })
        ah.onHideRequested = { hideCalled = true }
        ah.handleClick(at: NSPoint(x: 0, y: 0))
        XCTAssertFalse(hideCalled)
    }

    func test_install_uninstall_idempotent() {
        let ah = KanbanSlidePanelAutoHide(viewModel: makeVM(), settings: KanbanSlidePanelSettings(defaults: defaults), panelFrameProvider: { .zero })
        ah.install(); ah.install()
        ah.uninstall(); ah.uninstall()
    }

    func test_currentResponderMarkedText_falseByDefault() {
        // 테스트 환경에서 NSApp.keyWindow == nil → false 가 나와야 한다.
        let ah = KanbanSlidePanelAutoHide(
            viewModel: makeVM(),
            settings: KanbanSlidePanelSettings(defaults: defaults),
            panelFrameProvider: { .zero }
        )
        XCTAssertFalse(ah.shouldSuspend())
    }
}
