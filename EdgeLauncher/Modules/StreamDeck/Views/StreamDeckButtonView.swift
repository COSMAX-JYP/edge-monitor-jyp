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
        // Tile content sizes to the cell; icon scale is per-button (default 0.5)
        // so the user can dial how much of the cell the glyph or image fills.
        GeometryReader { proxy in
            let cell = min(proxy.size.width, proxy.size.height)
            let iconSize = cell * button.icon.effectiveScale
            let labelSize = max(cell * 0.13, 14)
            let hasLabel = !button.label.isEmpty
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.fromHex(button.backgroundHex) ?? Color.secondary.opacity(0.2))
                VStack(spacing: cell * 0.04) {
                    iconView(size: iconSize)
                        .frame(maxWidth: .infinity)
                    if hasLabel {
                        Text(button.label)
                            .font(labelFont(size: labelSize))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(labelColor)
                            .minimumScaleFactor(0.6)
                    }
                }
                // When a label is present, bias the icon toward the top so the label
                // gets a clean reading area below it (instead of squeezing both in the
                // vertical center). With no label, stay centered like before.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: hasLabel ? .top : .center)
                .padding(.horizontal, cell * 0.06)
                .padding(.top, hasLabel ? cell * 0.10 : cell * 0.06)
                .padding(.bottom, cell * 0.06)
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

    private var labelColor: Color {
        if let hex = button.labelColorHex, !hex.isEmpty, let c = Color.fromHex(hex) {
            return c
        }
        return Color.fromHex(button.foregroundHex) ?? .white
    }

    private func labelFont(size: CGFloat) -> Font {
        if let name = button.labelFontName, !name.isEmpty {
            return Font.custom(name, size: size).weight(.semibold)
        }
        return .system(size: size, weight: .semibold)
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
        case .image:
            if let nsImage = ButtonIconStorage.shared.image(forFilename: button.icon.value) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: size, weight: .regular))
                    .foregroundStyle(fg.opacity(0.6))
            }
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
