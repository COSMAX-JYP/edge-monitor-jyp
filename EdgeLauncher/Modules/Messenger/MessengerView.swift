import SwiftUI

struct MessengerView: View {
    var body: some View {
        HStack(spacing: 0) {
            card(title: "Slack", icon: "number", color: .purple, count: "3")
            Divider()
            card(title: "Discord", icon: "gamecontroller", color: .indigo, count: "12")
            Divider()
            card(title: "iMessage", icon: "message.fill", color: .green, count: "1")
            Divider()
            card(title: "Mail", icon: "envelope.fill", color: .blue, count: "27")
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func card(title: String, icon: String, color: Color, count: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text("\(count) 미확인")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("연동 예정")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
