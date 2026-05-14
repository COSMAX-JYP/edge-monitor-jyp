import AppKit

enum TouchPanGestureInstaller {
    static func install(on scrollView: NSScrollView) -> TouchScrollCoordinator {
        let coordinator = TouchScrollCoordinator()
        coordinator.scrollView = scrollView
        let pan = NSPanGestureRecognizer(target: coordinator, action: #selector(TouchScrollCoordinator.handlePan(_:)))
        pan.numberOfTouchesRequired = 1
        pan.buttonMask = 1
        scrollView.addGestureRecognizer(pan)
        return coordinator
    }
}

final class TouchScrollCoordinator: NSObject {
    weak var scrollView: NSScrollView?
    private var startOffsetY: CGFloat = 0

    @objc func handlePan(_ recognizer: NSPanGestureRecognizer) {
        guard let scrollView else { return }
        let translation = recognizer.translation(in: scrollView)

        switch recognizer.state {
        case .began:
            startOffsetY = scrollView.contentView.bounds.origin.y
        case .changed:
            let documentHeight = scrollView.documentView?.frame.height ?? 0
            let viewportHeight = scrollView.contentView.bounds.height
            let maxOffset = max(0, documentHeight - viewportHeight)
            var origin = scrollView.contentView.bounds.origin
            origin.y = min(max(0, startOffsetY - translation.y), maxOffset)
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        default:
            break
        }
    }
}
