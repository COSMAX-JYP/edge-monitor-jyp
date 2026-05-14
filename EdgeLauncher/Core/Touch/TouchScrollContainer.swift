import AppKit
import SwiftUI

struct TouchScrollContainer<Content: View>: NSViewRepresentable {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .allowed

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hosting

        NSLayoutConstraint.activate([
            hosting.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            hosting.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
        ])

        let coordinator = context.coordinator
        coordinator.scrollView = scrollView
        let pan = NSPanGestureRecognizer(target: coordinator, action: #selector(TouchScrollCoordinator.handlePan(_:)))
        pan.numberOfTouchesRequired = 1
        pan.buttonMask = 1
        scrollView.addGestureRecognizer(pan)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let host = nsView.documentView as? NSHostingView<Content> {
            host.rootView = content
        }
    }

    func makeCoordinator() -> TouchScrollCoordinator {
        TouchScrollCoordinator()
    }
}
