import SwiftUI

struct LauncherView: View {
    private let apps: [(String, String, Color)] = [
        ("Safari", "safari", .blue),
        ("Mail", "envelope.fill", .blue),
        ("Notes", "note.text", .yellow),
        ("Calendar", "calendar", .red),
        ("Reminders", "checklist", .orange),
        ("Music", "music.note", .pink),
        ("Photos", "photo", .purple),
        ("Maps", "map", .green),
        ("Terminal", "terminal", .black),
        ("Xcode", "hammer", .indigo),
        ("Slack", "number", .purple),
        ("Spotify", "music.note.list", .green),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: 8), spacing: 24) {
                ForEach(apps, id: \.0) { app in
                    appCell(name: app.0, icon: app.1, color: app.2)
                }
            }
            .padding(32)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func appCell(name: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 16)
                .fill(color.gradient)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                )
                .shadow(color: color.opacity(0.3), radius: 8, y: 4)
            Text(name)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
        }
    }
}
