import SwiftUI

struct EventDetailPanel: View {
    let event: TimelineEvent
    let calendars: [CalendarChoice]
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onDismiss: () -> Void
    var onRespond: ((GraphCalendarProvider.ResponseAction, String?) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(event.title)
                    .font(.appTitle)
                    .lineLimit(2)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark").font(.appBody)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.escape, modifiers: [])
            }
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.appCallout)
                    .foregroundStyle(.secondary)
                Text(timeLabel)
                    .font(.appCalloutMono)
            }
            if let location = event.location, !location.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse").font(.appCallout).foregroundStyle(.secondary)
                    Text(location).font(.appCallout)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "calendar").font(.appCallout).foregroundStyle(calendarColor ?? .secondary)
                Text(calendarTitle).font(.appCallout).foregroundStyle(.secondary)
            }
            if !event.attendees.isEmpty {
                Divider()
                Text("참석자").font(.appFootnote).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(event.attendees.enumerated()), id: \.offset) { _, a in
                        HStack(spacing: 6) {
                            Image(systemName: responseIcon(a.response))
                                .font(.appCallout)
                                .foregroundStyle(responseColor(a.response))
                            Text(a.name.isEmpty ? a.email : a.name)
                                .font(.appCallout)
                        }
                    }
                }
            }
            if let notes = event.notes, !notes.isEmpty {
                Divider()
                Text("노트").font(.appFootnote).foregroundStyle(.secondary)
                ScrollView {
                    Text(notes)
                        .font(.appCallout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 240)
            }
            if let url = event.url {
                Divider()
                Link(destination: url) {
                    Label(meetingLabel(url), systemImage: "link")
                }
                .font(.appCallout)
            }
            if case .outlook = event.source, onRespond != nil {
                if event.isOrganizer {
                    Divider()
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundStyle(.blue)
                        Text("주최자입니다. 응답은 참석자만 가능합니다.")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Divider()
                    Text("응답").font(.appFootnote).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Button {
                            onRespond?(.accept, nil)
                        } label: { Label("수락", systemImage: "checkmark.circle.fill").font(.appCallout) }
                        .buttonStyle(.borderedProminent).tint(.green)
                        Button {
                            onRespond?(.tentative, nil)
                        } label: { Label("잠정", systemImage: "questionmark.circle").font(.appCallout) }
                        .buttonStyle(.bordered).tint(.orange)
                        Button {
                            onRespond?(.decline, nil)
                        } label: { Label("거절", systemImage: "xmark.circle").font(.appCallout) }
                        .buttonStyle(.bordered).tint(.red)
                    }
                }
            }
            Spacer()
            HStack {
                Button("편집", action: onEdit).font(.appBody)
                Button("삭제", role: .destructive, action: onDelete).font(.appBody)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(Rectangle().fill(.background))
        .overlay(alignment: .leading) {
            Divider()
        }
    }

    private var timeLabel: String {
        if event.isAllDay { return "종일" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: event.start)) — \(f.string(from: event.end))"
    }

    private var calendarTitle: String {
        if case .apple(let id) = event.source,
           let match = calendars.first(where: { $0.id == id }) {
            return match.title
        }
        return event.source.displayName
    }

    private var calendarColor: Color? {
        if let hex = event.colorHex, let parsed = Color.fromHex(hex) { return parsed }
        return nil
    }

    private func meetingLabel(_ url: URL) -> String {
        let s = url.absoluteString
        if s.contains("teams.microsoft") { return "Teams 회의 열기" }
        if s.contains("zoom.us") { return "Zoom 회의 열기" }
        if s.contains("meet.google") { return "Google Meet 열기" }
        return s
    }

    private func responseIcon(_ s: Attendee.ResponseStatus) -> String {
        switch s {
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .tentative: return "questionmark.circle"
        case .needsAction: return "circle"
        case .unknown: return "circle"
        }
    }

    private func responseColor(_ s: Attendee.ResponseStatus) -> Color {
        switch s {
        case .accepted: return .green
        case .declined: return .red
        case .tentative: return .orange
        default: return .secondary
        }
    }
}
