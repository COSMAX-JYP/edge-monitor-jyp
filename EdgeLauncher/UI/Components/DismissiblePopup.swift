import SwiftUI

extension View {
    func dismissiblePopup<PopupContent: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content popupContent: @escaping () -> PopupContent
    ) -> some View {
        modifier(
            BoolDismissiblePopupModifier(
                isPresented: isPresented,
                onDismiss: onDismiss,
                popupContent: popupContent
            )
        )
    }

    func dismissiblePopup<Item: Identifiable, PopupContent: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content popupContent: @escaping (Item) -> PopupContent
    ) -> some View {
        modifier(
            ItemDismissiblePopupModifier(
                item: item,
                onDismiss: onDismiss,
                popupContent: popupContent
            )
        )
    }
}

private struct BoolDismissiblePopupModifier<PopupContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    let popupContent: () -> PopupContent

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    DismissiblePopupOverlay {
                        dismiss()
                    } content: {
                        popupContent()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
            .animation(.easeOut(duration: 0.16), value: isPresented)
    }

    private func dismiss() {
        isPresented = false
        onDismiss?()
    }
}

private struct ItemDismissiblePopupModifier<Item: Identifiable, PopupContent: View>: ViewModifier {
    @Binding var item: Item?
    let onDismiss: (() -> Void)?
    let popupContent: (Item) -> PopupContent

    func body(content: Content) -> some View {
        content
            .overlay {
                if let item {
                    DismissiblePopupOverlay {
                        dismiss()
                    } content: {
                        popupContent(item)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
            .animation(.easeOut(duration: 0.16), value: item?.id)
    }

    private func dismiss() {
        item = nil
        onDismiss?()
    }
}

private struct DismissiblePopupOverlay<PopupContent: View>: View {
    let onOutsideTap: () -> Void
    let content: () -> PopupContent

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onOutsideTap)

            content()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.38), radius: 34, y: 18)
                .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(10_000)
    }
}
