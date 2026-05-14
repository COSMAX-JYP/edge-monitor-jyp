import AppKit
import Combine

@MainActor
final class ChromeVisibilityController: ObservableObject {
    @Published var chromeVisible: Bool = true

    private var idleTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scheduleHide() }
        })
        observers.append(center.addObserver(forName: NSWindow.didExitFullScreenNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.idleTimer?.invalidate()
                self?.chromeVisible = true
            }
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func notifyMouseMoved() {
        chromeVisible = true
        scheduleHide()
    }

    private func scheduleHide() {
        idleTimer?.invalidate()
        guard let window = NSApp.mainWindow, window.styleMask.contains(.fullScreen) else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.chromeVisible = false
            }
        }
    }
}
