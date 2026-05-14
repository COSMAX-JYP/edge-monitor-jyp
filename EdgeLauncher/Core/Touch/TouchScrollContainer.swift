import AppKit
import SwiftUI

struct TouchScrollContainer<Content: View>: NSViewRepresentable {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = true
        scrollView.documentView = hosting
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .allowed
        context.coordinator.coordinator = TouchPanGestureInstaller.install(on: scrollView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let host = nsView.documentView as? NSHostingView<Content> {
            host.rootView = content
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var coordinator: TouchScrollCoordinator?
    }
}
