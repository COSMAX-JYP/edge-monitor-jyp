import SwiftUI

struct CalendarSidebarView: View {
    @Bindable var viewModel: TimelineViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("캘린더")
                    .font(.appBodyBold)
                Spacer()
                Button {
                    viewModel.toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.appCallout)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("b", modifiers: .command)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(groupedCalendars(), id: \.0) { group in
                        groupSection(title: group.0, calendars: group.1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .frame(width: 240)
        .background(.regularMaterial)
    }

    private func groupSection(title: String, calendars: [CalendarChoice]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.appCaptionBold)
                .foregroundStyle(.secondary)
            ForEach(calendars, id: \.id) { calendar in
                calendarRow(calendar)
            }
        }
    }

    private func calendarRow(_ calendar: CalendarChoice) -> some View {
        let visible = viewModel.visibilityStore.isVisible(calendar.id)
        let color = resolveColor(for: calendar)
        return HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(calendar.title)
                .font(.appFootnote)
                .lineLimit(1)
            Spacer()
            Toggle("", isOn: Binding(
                get: { visible },
                set: { _ in viewModel.toggleCalendarVisibility(calendar.id) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
        }
    }

    private func resolveColor(for calendar: CalendarChoice) -> Color {
        if let custom = viewModel.visibilityStore.color(for: calendar.id),
           let parsed = Color.fromHex(custom) {
            return parsed
        }
        if let hex = calendar.colorHex, let parsed = Color.fromHex(hex) {
            return parsed
        }
        return .accentColor
    }

    private func groupedCalendars() -> [(String, [CalendarChoice])] {
        var apple: [CalendarChoice] = []
        var outlook: [CalendarChoice] = []
        var other: [CalendarChoice] = []
        for cal in viewModel.calendars {
            let source = cal.sourceTitle.lowercased()
            if source.contains("outlook") || source.contains("microsoft") || source.contains("@") {
                outlook.append(cal)
            } else if source.contains("icloud") || source.contains("local") || source.contains("apple") || source.contains("on my mac") || source.contains("birthday") || source.contains("holiday") {
                apple.append(cal)
            } else {
                other.append(cal)
            }
        }
        var groups: [(String, [CalendarChoice])] = []
        if !apple.isEmpty { groups.append(("Apple", apple)) }
        if !outlook.isEmpty { groups.append(("Outlook", outlook)) }
        if !other.isEmpty { groups.append(("기타", other)) }
        return groups
    }
}
