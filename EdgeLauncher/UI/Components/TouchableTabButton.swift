import SwiftUI

struct TouchableTabButton: View {
    let iconName: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 40, weight: .medium))
                    .frame(width: 78, height: 78)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isActive ? Color.accentColor.opacity(0.25) : Color.clear)
                    )
                Text(title)
                    .font(.system(size: 15))
                    .lineLimit(1)
            }
            .frame(width: 120, height: 120)
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
    .frame(width: 155)
}
