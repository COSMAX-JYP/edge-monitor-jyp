import SwiftUI

enum EdgeTheme {
    static let sidebarWidth: CGFloat = 496
    static let statusHeight: CGFloat = 42
    static let controlRadius: CGFloat = 8
    static let tabTileWidth: CGFloat = 112
    static let tabTileHeight: CGFloat = 112

    static let cyan = Color(red: 0.12, green: 0.82, blue: 1.0)
    static let lime = Color(red: 0.63, green: 0.95, blue: 0.33)
    static let amber = Color(red: 1.0, green: 0.64, blue: 0.24)
    static let coral = Color(red: 1.0, green: 0.34, blue: 0.30)

    static func appBackground(isLight: Bool) -> LinearGradient {
        if isLight {
            return LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.98, blue: 1.0),
                    Color(red: 0.90, green: 0.94, blue: 0.97),
                    Color(red: 0.98, green: 0.98, blue: 0.94),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.05, blue: 0.07),
                Color(red: 0.07, green: 0.09, blue: 0.12),
                Color(red: 0.03, green: 0.08, blue: 0.09),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func railFill(isLight: Bool) -> Color {
        isLight ? Color.white.opacity(0.74) : Color.black.opacity(0.28)
    }

    static func panelFill(isLight: Bool) -> Color {
        isLight ? Color.white.opacity(0.78) : Color.white.opacity(0.075)
    }

    static func elevatedFill(isLight: Bool) -> Color {
        isLight ? Color.white.opacity(0.92) : Color.white.opacity(0.12)
    }

    static func stroke(isLight: Bool) -> Color {
        isLight ? Color.black.opacity(0.10) : Color.white.opacity(0.12)
    }

    static func softShadow(isLight: Bool) -> Color {
        isLight ? Color.black.opacity(0.14) : Color.black.opacity(0.35)
    }

    static func activeGradient(isLight: Bool) -> LinearGradient {
        LinearGradient(
            colors: isLight
                ? [cyan.opacity(0.92), lime.opacity(0.82)]
                : [cyan.opacity(0.58), lime.opacity(0.42)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct EdgeIconButton: View {
    let systemName: String
    let help: String
    let isLight: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        systemName: String,
        help: String,
        isLight: Bool,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.help = help
        self.isLight = isLight
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isDisabled ? Color.secondary.opacity(0.45) : Color.primary)
                .frame(width: 34, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: EdgeTheme.controlRadius)
                        .fill(EdgeTheme.elevatedFill(isLight: isLight))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EdgeTheme.controlRadius)
                        .stroke(EdgeTheme.stroke(isLight: isLight), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(help)
    }
}

struct EdgeStatusPill: View {
    let title: String
    let value: String
    let color: Color
    let isLight: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.65), radius: 5)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: EdgeTheme.controlRadius)
                .fill(EdgeTheme.panelFill(isLight: isLight))
        )
        .overlay(
            RoundedRectangle(cornerRadius: EdgeTheme.controlRadius)
                .stroke(EdgeTheme.stroke(isLight: isLight), lineWidth: 1)
        )
    }
}
