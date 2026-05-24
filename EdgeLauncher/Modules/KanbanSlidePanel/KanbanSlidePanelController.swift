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

    // MARK: - frame 계산
    static func computeTargetFrame(screenFrame: NSRect, panelWidth: Double, heightRatio: Double) -> NSRect {
        let height = screenFrame.height * CGFloat(heightRatio)
        let y = screenFrame.minY + (screenFrame.height - height) / 2
        let x = screenFrame.maxX - CGFloat(panelWidth)
        return NSRect(x: x, y: y, width: CGFloat(panelWidth), height: height)
    }

    static func computeStartFrame(screenFrame: NSRect, panelWidth: Double, heightRatio: Double) -> NSRect {
        var f = computeTargetFrame(screenFrame: screenFrame, panelWidth: panelWidth, heightRatio: heightRatio)
        f.origin.x = screenFrame.maxX
        return f
    }

    // MARK: - AutoHide 통합
    fileprivate func ensureAutoHideCreated() {
        guard autoHide == nil else { return }
        guard let panel, let vm = panelViewModel else { return }
        let ah = KanbanSlidePanelAutoHide(viewModel: vm, settings: settings, panelFrameProvider: { [weak panel] in
            panel?.frame ?? .zero
        })
        ah.onHideRequested = { [weak self] in self?.hide() }
        ah.onEscapeRequested = { [weak self] in self?.hide() }
        panel.delegate = ah
        self.autoHide = ah
    }

    // MARK: - 내부
    fileprivate func ensurePanelCreated() {
        guard panel == nil else { return }
        let vm = KanbanViewModel(store: store)
        self.panelViewModel = vm
        let root = KanbanSlidePanelView(
            viewModel: vm,
            settings: settings,
            onRequestClose: { [weak self] in self?.hide() }
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
        let target = Self.computeTargetFrame(screenFrame: screenFrame, panelWidth: settings.panelWidth, heightRatio: 0.92)
        let start = Self.computeStartFrame(screenFrame: screenFrame, panelWidth: settings.panelWidth, heightRatio: 0.92)
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
        let outFrame = Self.computeStartFrame(screenFrame: screenFrame, panelWidth: settings.panelWidth, heightRatio: 0.92)
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

