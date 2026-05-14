import SwiftUI

struct TouchableTabButton: View {
    let iconName: String
    let title: String
    let isActive: Bool
    let badgeCount: Int
    let action: () -> Void

    init(iconName: String, title: String, isActive: Bool, badgeCount: Int = 0, action: @escaping () -> Void) {
        self.iconName = iconName
        self.title = title
        self.isActive = isActive
        self.badgeCount = badgeCount
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: iconName)
                        .font(.system(size: 40, weight: .medium))
                        .frame(width: 78, height: 78)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isActive ? Color.accentColor.opacity(0.25) : Color.clear)
                        )

                    if badgeCount > 0 {
                        Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(Capsule().fill(Color.red))
                            .overlay(Capsule().stroke(Color(NSColor.windowBackgroundColor), lineWidth: 2))
                            .offset(x: 6, y: -4)
                    }
                }
                Text(title)
                    .font(.system(size: 15))
                    .lineLimit(1)
            }
            .frame(width: 120, height: 120)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badgeCount > 0 ? "\(title), 미확인 \(badgeCount)" : title)
    }
}
