import AppKit

@MainActor
final class EdgeWindowController {
    private let displayService: XeneonDisplayService

    init(displayService: XeneonDisplayService) {
        self.displayService = displayService
    }

    func moveMainWindowToEdge() {
        guard let window = NSApp.mainWindow ?? NSApp.windows.first else { return }
        guard let screen = displayService.edgeScreen else {
            NSSound.beep()
            return
        }
        let frame = screen.visibleFrame
        window.setFrame(frame, display: true, animate: true)
    }

    func toggleFullScreen() {
        guard let window = NSApp.mainWindow ?? NSApp.windows.first else { return }
        window.toggleFullScreen(nil)
    }

    /// 항상 풀스크린 상태로 들어가도록 보장 (이미 풀스크린이면 무시).
    func enterFullScreenIfNeeded() {
        guard let window = NSApp.mainWindow ?? NSApp.windows.first else { return }
        window.collectionBehavior.insert(.fullScreenPrimary)
        if !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }
}

extension Notification.Name {
    static let edgeMoveRequested = Notification.Name("edge.move.requested")
}
