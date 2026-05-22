import SwiftUI

struct DismissiblePopupLayout: Equatable {
    enum Mode: Equatable {
        case centered
        case fillContainer(inset: CGFloat)
    }

    var mode: Mode
    var cornerRadius: CGFloat

    static let centered = DismissiblePopupLayout(mode: .centered, cornerRadius: 20)

    static func fillContainer(inset: CGFloat = 0, cornerRadius: CGFloat = 0) -> DismissiblePopupLayout {
        DismissiblePopupLayout(mode: .fillContainer(inset: inset), cornerRadius: cornerRadius)
    }
}

extension View {
    func dismissiblePopup<PopupContent: View>(
        isPresented: Binding<Bool>,
        layout: DismissiblePopupLayout = .centered,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content popupContent: @escaping () -> PopupContent
    ) -> some View {
        modifier(
            BoolDismissiblePopupModifier(
                isPresented: isPresented,
                layout: layout,
                onDismiss: onDismiss,
                popupContent: popupContent
            )
        )
    }

    func dismissiblePopup<Item: Identifiable, PopupContent: View>(
        item: Binding<Item?>,
        layout: DismissiblePopupLayout = .centered,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content popupContent: @escaping (Item) -> PopupContent
    ) -> some View {
        modifier(
            ItemDismissiblePopupModifier(
                item: item,
                layout: layout,
                onDismiss: onDismiss,
                popupContent: popupContent
            )
        )
    }
}

private struct BoolDismissiblePopupModifier<PopupContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let layout: DismissiblePopupLayout
    let onDismiss: (() -> Void)?
    let popupContent: () -> PopupContent

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                DismissiblePopupOverlay(layout: layout) {
                    isPresented = false
                    onDismiss?()
                } content: {
                    popupContent()
                }
                .transition(.opacity)
            }
        }
    }
}

private struct ItemDismissiblePopupModifier<Item: Identifiable, PopupContent: View>: ViewModifier {
    @Binding var item: Item?
    let layout: DismissiblePopupLayout
    let onDismiss: (() -> Void)?
    let popupContent: (Item) -> PopupContent

    func body(content: Content) -> some View {
        content.overlay {
            if let item {
                DismissiblePopupOverlay(layout: layout) {
                    self.item = nil
                    onDismiss?()
                } content: {
                    popupContent(item)
                }
                .transition(.opacity)
            }
        }
    }
}

private struct DismissiblePopupOverlay<PopupContent: View>: View {
    let layout: DismissiblePopupLayout
    let onOutsideTap: () -> Void
    let content: () -> PopupContent

    var body: some View {
        // Container-relative sizing: GeometryReader reads the OVERLAY parent (e.g. the
        // StreamDeckView VStack), not the screen. This is the architectural fix —
        // popups stay within their host's bounds and can't slide behind the sidebar.
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.42)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onOutsideTap)

                popup(in: proxy.size)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .zIndex(10_000)
    }

    @ViewBuilder
    private func popup(in size: CGSize) -> some View {
        switch layout.mode {
        case .centered:
            decorated(content())
        case .fillContainer(let inset):
            decorated(
                content()
                    .frame(
                        width: max(size.width - inset * 2, 0),
                        height: max(size.height - inset * 2, 0),
                        alignment: .topLeading
                    )
            )
            .padding(inset)
        }
    }

    private func decorated<V: View>(_ view: V) -> some View {
        let shape = RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
        return view
            .background(.regularMaterial, in: shape)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.38), radius: 34, y: 18)
            .contentShape(Rectangle())
            .onTapGesture {}
    }
}
