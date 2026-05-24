import AppKit
import Carbon.HIToolbox

@MainActor
final class KanbanSlidePanelAutoHide: NSObject, NSWindowDelegate {
    let viewModel: KanbanViewModel
    let settings: KanbanSlidePanelSettings
    let panelFrameProvider: () -> NSRect

    var onHideRequested: (() -> Void)?
    var onEscapeRequested: (() -> Void)?
    /// 드래그 진행 중 플래그 (KanbanSlidePanelView 가 set)
    var isDragging: Bool = false

    /// Controller 가 show 완료 시점에 set — windowDidResignKey 의 grace period 판단용.
    var lastShowTimestamp: Date?

    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var localKeyMonitor: Any?

    init(viewModel: KanbanViewModel, settings: KanbanSlidePanelSettings, panelFrameProvider: @escaping () -> NSRect) {
        self.viewModel = viewModel
        self.settings = settings
        self.panelFrameProvider = panelFrameProvider
    }

    func shouldSuspend() -> Bool {
        if settings.isPinned { return true }
        if !settings.autoHideOnBlur { return true }
        if viewModel.editingCard != nil { return true }
        if viewModel.detailCard != nil { return true }
        if viewModel.editingBoard != nil { return true }
        if viewModel.isManagingLabels { return true }
        if viewModel.pendingDeleteCard != nil { return true }
        if viewModel.pendingDeleteBoardId != nil { return true }
        if isDragging { return true }
        return false
    }

    func handleClick(at globalPoint: NSPoint) {
        if shouldSuspend() { return }
        let frame = panelFrameProvider()
        if frame.contains(globalPoint) { return }
        onHideRequested?()
    }

    func handleEscape() {
        if settings.isPinned { return }
        if !settings.autoHideOnEscape { return }
        // 편집 시트가 열려 있으면 시트만 닫고 패널 유지
        if viewModel.editingCard != nil { viewModel.cancelEditing(); return }
        if viewModel.detailCard != nil { viewModel.dismissDetail(); return }
        if viewModel.isManagingLabels { viewModel.closeLabelManager(); return }
        onEscapeRequested?()
    }

    func install() {
        if globalMouseMonitor == nil {
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in self?.handleClick(at: NSEvent.mouseLocation) }
            }
        }
        if localMouseMonitor == nil {
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                Task { @MainActor in self?.handleClick(at: NSEvent.mouseLocation) }
                return event
            }
        }
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == UInt16(kVK_Escape) {
                    Task { @MainActor in self?.handleEscape() }
                    return nil
                }
                return event
            }
        }
    }

    func uninstall() {
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m); globalMouseMonitor = nil }
        if let m = localMouseMonitor { NSEvent.removeMonitor(m); localMouseMonitor = nil }
        if let m = localKeyMonitor { NSEvent.removeMonitor(m); localKeyMonitor = nil }
    }

    // MARK: NSWindowDelegate (v2.1 — codex 권고 반영해 격하)
    /// resignKey 는 주 트리거가 아니라 보조 신호.
    /// false-positive (sleep/wake, Mission Control, Stage Manager, sheet/menu opening,
    /// 앱 비활성 전환, display reconfig, 최근 show animation 직후 비활성화) 가 흔하므로
    /// 다음 조건을 모두 만족할 때에만 hide 한다:
    /// 1. suspend 평가 통과 (편집 시트 등 미열림, 핀 아님)
    /// 2. `NSApp.isActive == true` (앱 비활성 전환 중이면 skip)
    /// 3. 최근 show 애니메이션으로부터 grace period (0.25s) 경과
    /// 4. 윈도우가 실제로 visible
    nonisolated func windowDidResignKey(_ notification: Notification) {
        Task { @MainActor in
            if self.shouldSuspend() { return }
            if !NSApp.isActive { return }
            if Date().timeIntervalSince(self.lastShowTimestamp ?? .distantPast) < 0.25 { return }
            guard let win = notification.object as? NSWindow, win.isVisible else { return }
            self.onHideRequested?()
        }
    }
}
