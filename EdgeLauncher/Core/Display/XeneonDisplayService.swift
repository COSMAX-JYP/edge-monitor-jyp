import AppKit
import Combine

final class XeneonDisplayService: ObservableObject {
    @Published private(set) var edgeScreen: NSScreen?

    private var cancellable: AnyCancellable?

    init() {
        refresh()
        cancellable = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        edgeScreen = NSScreen.screens.first { screen in
            let size = screen.frame.size
            return Self.isEdgeDisplay(width: Int(size.width), height: Int(size.height))
        }
    }

    static func isEdgeDisplay(width: Int, height: Int) -> Bool {
        let widthOK = abs(width - 2560) <= 4
        let heightOK = abs(height - 720) <= 4
        return widthOK && heightOK
    }
}
