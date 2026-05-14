import SwiftUI

struct TouchableTabButton: View {
    let iconName: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 28, weight: .medium))
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isActive ? Color.accentColor.opacity(0.25) : Color.clear)
                    )
                Text(title)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .frame(width: 84, height: 84)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#Preview {
    VStack {
        TouchableTabButton(iconName: "play.rectangle.fill", title: "YouTube", isActive: true) {}
        TouchableTabButton(iconName: "music.note", title: "Music", isActive: false) {}
    }
    .padding()
    .frame(width: 110)
}
