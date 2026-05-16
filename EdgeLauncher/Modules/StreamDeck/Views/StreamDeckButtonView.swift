import SwiftUI

struct StreamDeckButtonView: View {
    let button: StreamDeckButton
    let isExecuting: Bool
    let isFlashing: Bool
    let isEditing: Bool
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        // Tile content sizes to the cell; we let the icon take ~55% and the label ~20%
        // so neither feels like it's floating in whitespace.
        GeometryReader { proxy in
            let cell = min(proxy.size.width, proxy.size.height)
            let iconSize = cell * 0.5
            let labelSize = max(cell * 0.13, 14)
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.fromHex(button.backgroundHex) ?? Color.secondary.opacity(0.2))
                VStack(spacing: cell * 0.05) {
                    iconView(size: iconSize)
                        .frame(maxWidth: .infinity)
                    if !button.label.isEmpty {
                        Text(button.label)
                            .font(.system(size: labelSize, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.fromHex(button.foregroundHex) ?? .white)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(cell * 0.06)
                if isExecuting {
                    ProgressView().controlSize(.regular)
                }
                if isFlashing {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.cyan, lineWidth: 3)
                }
                if isEditing {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .foregroundStyle(.secondary)
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                onDelete()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.red, .white)
                            }
                            .buttonStyle(.plain)
                            .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                if isEditing { onEdit() } else { onTap() }
            }
            .contextMenu {
                Button("편집") { onEdit() }
                Button("삭제", role: .destructive) { onDelete() }
            }
        }
    }

    @ViewBuilder
    private func iconView(size: CGFloat) -> some View {
        let fg = Color.fromHex(button.foregroundHex) ?? .white
        switch button.icon.type {
        case .sfSymbol:
            Image(systemName: button.icon.value.isEmpty ? "square.dashed" : button.icon.value)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(fg)
        case .emoji:
            Text(button.icon.value.isEmpty ? "❔" : button.icon.value)
                .font(.system(size: size))
        }
    }
}

struct EmptySlotView: View {
    let isEditing: Bool
    var onTap: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width, proxy.size.height)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundStyle(.secondary.opacity(0.5))
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: cell * 0.3, weight: .light))
                        .foregroundStyle(.secondary.opacity(isEditing ? 1 : 0))
                )
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture {
                    if isEditing { onTap() }
                }
        }
    }
}
