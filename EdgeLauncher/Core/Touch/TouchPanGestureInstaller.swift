import AppKit

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
