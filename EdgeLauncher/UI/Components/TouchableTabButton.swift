import SwiftUI

struct TouchableTabButton: View {
    let iconName: String
    let title: String
    let isActive: Bool
    let badgeCount: Int
    let customIcon: IconCustomization?
    let action: () -> Void
    @AppStorage("app.themeMode") private var themeMode = "dark"
    @State private var isHovering = false

    init(iconName: String, title: String, isActive: Bool, badgeCount: Int = 0, customIcon: IconCustomization? = nil, action: @escaping () -> Void) {
        self.iconName = iconName
        self.title = title
        self.isActive = isActive
        self.badgeCount = badgeCount
        self.customIcon = customIcon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    iconView
                        .frame(width: 82, height: 62)

                    if badgeCount > 0 {
                        Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .frame(minWidth: 24, minHeight: 24)
                            .background(Capsule().fill(Color.red))
                            .overlay(Capsule().stroke(EdgeTheme.railFill(isLight: isLightTheme), lineWidth: 2))
                            .offset(x: 12, y: -6)
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(width: 98)
            }
            .foregroundStyle(isActive ? activeForeground : inactiveForeground)
            .frame(width: EdgeTheme.tabTileWidth, height: EdgeTheme.tabTileHeight)
            .background(tileBackground)
            .overlay(tileStroke)
            .shadow(color: isActive ? EdgeTheme.cyan.opacity(isLightTheme ? 0.22 : 0.34) : .clear, radius: 10, y: 4)
            .scaleEffect(isHovering ? 1.035 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovering = hovering
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isActive)
        .accessibilityLabel(badgeCount > 0 ? "\(title), 미확인 \(badgeCount)" : title)
    }

    @ViewBuilder
    private var iconView: some View {
        if let custom = customIcon, let nsImage = custom.loadImage() {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .scaleEffect(custom.scale)
                .offset(x: custom.offsetX, y: custom.offsetY)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: iconName)
                .font(.system(size: 48, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
        }
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: EdgeTheme.controlRadius)
            .fill(isActive ? EdgeTheme.activeGradient(isLight: isLightTheme) : LinearGradient(
                colors: [
                    EdgeTheme.panelFill(isLight: isLightTheme),
                    EdgeTheme.elevatedFill(isLight: isLightTheme).opacity(0.82),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
    }

    private var tileStroke: some View {
        RoundedRectangle(cornerRadius: EdgeTheme.controlRadius)
            .stroke(
                isActive ? Color.white.opacity(isLightTheme ? 0.56 : 0.24) : EdgeTheme.stroke(isLight: isLightTheme),
                lineWidth: 1
            )
    }

    private var activeForeground: Color {
        isLightTheme ? Color.black.opacity(0.82) : Color.white
    }

    private var inactiveForeground: Color {
        isLightTheme ? Color.black.opacity(0.72) : Color.white.opacity(0.72)
    }

    private var isLightTheme: Bool {
        themeMode == "light"
    }
}
