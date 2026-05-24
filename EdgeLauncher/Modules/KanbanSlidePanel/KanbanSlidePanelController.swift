import AppKit
import SwiftUI

@MainActor
final class KanbanSlidePanelController {
    enum State: Equatable { case hidden, animatingIn, shown, animatingOut }

    private(set) var state: State = .hidden
    var isPresented: Bool { state == .shown || state == .animatingIn }

    var animationsEnabled: Bool = true

    let store: KanbanStore
    let settings: KanbanSlidePanelSettings

    private var panel: KanbanSlidePanelWindow?
    private var hostingView: NSHostingView<KanbanSlidePanelView>?
    private var panelViewModel: KanbanViewModel?
    private var animationToken: Int = 0
    private var autoHide: KanbanSlidePanelAutoHide?
    private var wakeObserver: NSObjectProtocol?
    private var screenChangeObserver: NSObjectProtocol?

    init(store: KanbanStore, settings: KanbanSlidePanelSettings) {
        self.store = store
        self.settings = settings
    }

    func toggle() {
        switch state {
        case .hidden, .animatingOut: show()
        case .shown, .animatingIn: hide()
        }
    }

    func show() {
        if state == .shown { return }
        if state == .animatingIn { return }
        if !animationsEnabled {
            state = .shown
            return
        }
        animationToken &+= 1
        let myToken = animationToken
        state = .animatingIn
        performShowAnimation { [weak self] in
            guard let self else { return }
            if myToken == self.animationToken {
                self.state = .shown
            }
        }
    }

    func hide(animated: Bool = true) {
        if state == .hidden { return }
        if state == .animatingOut { return }
        if !animationsEnabled || !animated {
            state = .hidden
            return
        }
        animationToken &+= 1
        let myToken = animationToken
        state = .animatingOut
        performHideAnimation { [weak self] in
            guard let self else { return }
            if myToken == self.animationToken {
                self.state = .hidden
            }
        }
    }

    func setPinned(_ pinned: Bool) { settings.isPinned = pinned }

    func warmUp() { ensurePanelCreated() }

    /// 현재 패널이 표시된 디스플레이의 visibleFrame.width 를 읽어 패널 폭을 그 값으로 갱신.
    /// 패널이 떠 있으면 즉시 setFrame, 아니면 settings 만 갱신 (다음 호출에 적용).
    func resizePanelToFullScreenWidth() {
        let screen = resolveTargetScreen()
        let width = Double(screen.visibleFrame.width)
        settings.panelWidth = width
        if let panel, isPresented {
            let target = Self.computeTargetFrame(
                screenFrame: screen.visibleFrame,
                panelWidth: width,
                panelHeight: settings.panelHeight,
                heightRatio: 0.92
            )
            panel.setFrame(target, display: true, animate: true)
        }
    }

    // MARK: - System observers (sleep/wake, display reconfig)
    func installSystemObservers(rebindHotKey: @escaping @MainActor () -> Void) {
        let wsc = NSWorkspace.shared.notificationCenter
        if wakeObserver == nil {
            wakeObserver = wsc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in rebindHotKey() }
            }
        }
        if screenChangeObserver == nil {
            screenChangeObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleScreenParametersChanged() }
            }
        }
    }

    private func handleScreenParametersChanged() {
        guard isPresented, let panel else { return }
        let screenFrame = resolveTargetScreen().visibleFrame
        let target = Self.computeTargetFrame(screenFrame: screenFrame, panelWidth: settings.panelWidth, panelHeight: settings.panelHeight, heightRatio: 0.92)
        panel.setFrame(target, display: true, animate: true)
    }

    // MARK: - frame 계산
    static func computeTargetFrame(screenFrame: NSRect, panelWidth: Double, heightRatio: Double) -> NSRect {
        let height = screenFrame.height * CGFloat(heightRatio)
        let y = screenFrame.minY + (screenFrame.height - height) / 2
        let x = screenFrame.maxX - CGFloat(panelWidth)
        return NSRect(x: x, y: y, width: CGFloat(panelWidth), height: height)
    }

    /// 사용자가 저장한 height(`panelHeight`>0) 가 있으면 절대값을, 없으면 화면 비율(heightRatio)
    /// 기반으로 계산. height 가 화면을 넘으면 screen.height 로 클램프.
    static func computeTargetFrame(screenFrame: NSRect, panelWidth: Double, panelHeight: Double, heightRatio: Double) -> NSRect {
        let h: CGFloat
        if panelHeight > 0 {
            h = min(CGFloat(panelHeight), screenFrame.height)
        } else {
            h = screenFrame.height * CGFloat(heightRatio)
        }
        let y = screenFrame.minY + (screenFrame.height - h) / 2
        let x = screenFrame.maxX - CGFloat(panelWidth)
        return NSRect(x: x, y: y, width: CGFloat(panelWidth), height: h)
    }

    static func computeStartFrame(screenFrame: NSRect, panelWidth: Double, heightRatio: Double) -> NSRect {
        var f = computeTargetFrame(screenFrame: screenFrame, panelWidth: panelWidth, heightRatio: heightRatio)
        f.origin.x = screenFrame.maxX
        return f
    }

    static func computeStartFrame(screenFrame: NSRect, panelWidth: Double, panelHeight: Double, heightRatio: Double) -> NSRect {
        var f = computeTargetFrame(screenFrame: screenFrame, panelWidth: panelWidth, panelHeight: panelHeight, heightRatio: heightRatio)
        f.origin.x = screenFrame.maxX
        return f
    }

    // MARK: - AutoHide 통합
    /// 사용자 요청: 단축키(Cmd+Shift+K) 토글만으로 펼침/접힘. 외부 클릭 / Esc /
    /// windowDidResignKey 자동 숨김 모두 비활성. 헤더의 닫기 버튼은 controller.hide()
    /// 를 직접 호출하므로 따로 유지.
    fileprivate func ensureAutoHideCreated() {
        // 의도적으로 빈 함수 — autoHide 인스턴스 생성 안 함.
    }

    // MARK: - 내부
    fileprivate func ensurePanelCreated() {
        guard panel == nil else { return }
        let vm = KanbanViewModel(store: store)
        self.panelViewModel = vm
        let root = KanbanSlidePanelView(
            viewModel: vm,
            settings: settings,
            onRequestClose: { [weak self] in self?.hide() },
            onResizeFullWidth: { [weak self] in self?.resizePanelToFullScreenWidth() }
        )
        let hosting = NSHostingView(rootView: root)
        self.hostingView = hosting
        let p = KanbanSlidePanelWindow(contentRect: NSRect(x: 0, y: 0, width: settings.panelWidth, height: 800))
        p.contentView = hosting
        self.panel = p
    }

    private func resolveTargetScreen() -> NSScreen {
        switch settings.targetDisplayPolicy {
        case .mainDisplay:
            return NSScreen.main ?? NSScreen.screens.first ?? .deepest!
        case .mouseLocation:
            let mouse = NSEvent.mouseLocation
            return NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main ?? NSScreen.screens.first!
        case .specific(let uuid):
            if let match = NSScreen.screens.first(where: { ($0.uniqueDisplayID ?? "") == uuid }) { return match }
            return NSScreen.main ?? NSScreen.screens.first!
        }
    }

    private func performShowAnimation(completion: @escaping () -> Void) {
        ensurePanelCreated()
        guard let panel else { completion(); return }
        let screenFrame = resolveTargetScreen().visibleFrame
        let target = Self.computeTargetFrame(screenFrame: screenFrame, panelWidth: settings.panelWidth, panelHeight: settings.panelHeight, heightRatio: 0.92)
        let start = Self.computeStartFrame(screenFrame: screenFrame, panelWidth: settings.panelWidth, panelHeight: settings.panelHeight, heightRatio: 0.92)
        panel.setFrame(start, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = settings.slideAnimationDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            self?.ensureAutoHideCreated()
            self?.autoHide?.lastShowTimestamp = Date()
            self?.autoHide?.install()
            completion()
        })
    }

    private func performHideAnimation(completion: @escaping () -> Void) {
        guard let panel else { completion(); return }
        let screenFrame = resolveTargetScreen().visibleFrame
        let outFrame = Self.computeStartFrame(screenFrame: screenFrame, panelWidth: settings.panelWidth, panelHeight: settings.panelHeight, heightRatio: 0.92)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = max(0.10, settings.slideAnimationDuration * 0.8)
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(outFrame, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.autoHide?.uninstall()
            self?.panel?.orderOut(nil)
            completion()
        })
    }
}

private extension NSScreen {
    var uniqueDisplayID: String? {
        guard let raw = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        return String(raw.uint32Value)
    }
}

