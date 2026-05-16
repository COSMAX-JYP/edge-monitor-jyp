import AppKit
import CoreGraphics

final class EdgeCursorGuard {
    private let displayService: XeneonDisplayService
    private var localEventMonitor: Any?
    private static var suppressLocalSyncUntil: Date = .distantPast

    init(displayService: XeneonDisplayService) {
        self.displayService = displayService
    }

    @MainActor
    func installEventMonitor() {
        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .leftMouseDragged]
            ) { [weak self] event in
                self?.handleLocal(event)
                return event
            }
        }
    }

    func uninstallEventMonitor() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
    }

    @MainActor
    private func handleLocal(_ event: NSEvent) {
        guard !Self.isLocalSyncSuppressed() else { return }
        guard let edgeScreen = displayService.edgeScreen else { return }
        let eventPoint = Self.screenPoint(of: event)
        guard edgeScreen.frame.contains(eventPoint) else { return }
        syncCursorIfDesynced(eventPoint: eventPoint, edgeFrame: edgeScreen.frame)
    }

    @MainActor
    private func syncCursorIfDesynced(eventPoint: CGPoint, edgeFrame: CGRect) {
        guard UserDefaults.standard.bool(forKey: "app.keepCursorOnEdgeForTouch") else { return }
        let current = NSEvent.mouseLocation
        if edgeFrame.contains(current) { return }
        CGWarpMouseCursorPosition(Self.quartzPoint(fromAppKitPoint: eventPoint))
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
    }

    @MainActor
    static func screenPoint(of event: NSEvent) -> CGPoint {
        if let window = event.window {
            return window.convertPoint(toScreen: event.locationInWindow)
        }
        return event.locationInWindow
    }

    static func mapToEdge(_ point: CGPoint, edgeFrame: CGRect) -> CGPoint {
        let sourceFrame = NSScreen.screens.first { $0.frame.contains(point) }?.frame
            ?? NSScreen.main?.frame
            ?? edgeFrame
        guard sourceFrame.width > 0, sourceFrame.height > 0 else {
            return CGPoint(x: edgeFrame.midX, y: edgeFrame.midY)
        }
        let nx = max(0, min(1, (point.x - sourceFrame.minX) / sourceFrame.width))
        let ny = max(0, min(1, (point.y - sourceFrame.minY) / sourceFrame.height))
        return CGPoint(
            x: edgeFrame.minX + nx * edgeFrame.width,
            y: edgeFrame.minY + ny * edgeFrame.height
        )
    }

    static func cursorTargetPoint(in screenFrame: CGRect) -> CGPoint {
        CGPoint(x: screenFrame.midX, y: screenFrame.midY)
    }

    static func touchSafeFrame(for screenFrame: CGRect) -> CGRect {
        screenFrame.insetBy(dx: 4, dy: 4)
    }

    static func quartzPoint(fromAppKitPoint point: CGPoint, mainScreenHeight: CGFloat? = nil) -> CGPoint {
        let height = mainScreenHeight ?? NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: point.x, y: height - point.y)
    }

    static func appKitPoint(fromQuartzPoint point: CGPoint, mainScreenHeight: CGFloat? = nil) -> CGPoint {
        let height = mainScreenHeight ?? NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: point.x, y: height - point.y)
    }

    static func suppressLocalSync(for interval: TimeInterval) {
        suppressLocalSyncUntil = Date().addingTimeInterval(interval)
    }

    static func isLocalSyncSuppressed(now: Date = Date()) -> Bool {
        now < suppressLocalSyncUntil
    }
}
