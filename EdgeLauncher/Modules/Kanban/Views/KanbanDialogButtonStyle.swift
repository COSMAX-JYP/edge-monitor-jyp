import SwiftUI

extension View {
    func kanbanDialogSecondaryButton() -> some View {
        self
            .buttonStyle(KanbanDialogActionButtonStyle(isProminent: false))
    }

    func kanbanDialogPrimaryButton() -> some View {
        self
            .buttonStyle(KanbanDialogActionButtonStyle(isProminent: true))
    }
}

private struct KanbanDialogActionButtonStyle: ButtonStyle {
    let isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(isProminent ? Color.white : Color.primary)
            .frame(minWidth: 126, minHeight: 58)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isProminent ? Color.accentColor : Color.primary.opacity(0.12))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isProminent ? 0.08 : 0.18), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
