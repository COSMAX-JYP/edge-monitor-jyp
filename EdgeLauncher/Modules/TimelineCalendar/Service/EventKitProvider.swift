import Foundation
import EventKit

@MainActor
final class EventKitProvider: CalendarProvider {
    let source: CalendarSourceKind = .apple

    private let store: EKEventStore

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    func fetchEvents(on day: Date) async throws -> [TimelineEvent] {
        try ensureAuthorized(readOnly: true)
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
        let events = store.events(matching: predicate)
        return events.map { EventKitProvider.convert($0) }
    }

    func availableCalendars() async throws -> [CalendarChoice] {
        try ensureAuthorized(readOnly: true)
        return store.calendars(for: .event).map { ek in
            CalendarChoice(
                id: ek.calendarIdentifier,
                title: ek.title,
                sourceTitle: ek.source.title,
                colorHex: Self.hexString(ek.cgColor),
                allowsModifications: ek.allowsContentModifications,
                providerKind: .apple
            )
        }
    }

    func defaultCalendarId() async throws -> String? {
        try ensureAuthorized(readOnly: true)
        if let def = store.defaultCalendarForNewEvents { return def.calendarIdentifier }
        return store.calendars(for: .event).first { $0.allowsContentModifications }?.calendarIdentifier
    }

    func saveEvent(_ draft: EventDraft) async throws -> TimelineEvent {
        try ensureAuthorized(readOnly: false)
        try validate(draft)
        guard let calendar = store.calendar(withIdentifier: draft.calendarId) else {
            throw CalendarProviderError.calendarNotFound(identifier: draft.calendarId)
        }
        guard calendar.allowsContentModifications else {
            throw CalendarProviderError.readOnlyCalendar
        }
        let event = EKEvent(eventStore: store)
        apply(draft: draft, to: event, calendar: calendar)
        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            throw CalendarProviderError.saveFailed(underlying: error)
        }
        return EventKitProvider.convert(event)
    }

    func updateEvent(_ event: TimelineEvent, draft: EventDraft) async throws -> TimelineEvent {
        try ensureAuthorized(readOnly: false)
        try validate(draft)
        guard let ek = store.calendarItem(withIdentifier: event.calendarItemIdentifier) as? EKEvent else {
            throw CalendarProviderError.eventNotFound(identifier: event.calendarItemIdentifier)
        }
        let targetCalendar = store.calendar(withIdentifier: draft.calendarId) ?? ek.calendar
        guard let targetCalendar, targetCalendar.allowsContentModifications else {
            throw CalendarProviderError.readOnlyCalendar
        }
        apply(draft: draft, to: ek, calendar: targetCalendar)
        do {
            try store.save(ek, span: .thisEvent, commit: true)
        } catch {
            throw CalendarProviderError.saveFailed(underlying: error)
        }
        return EventKitProvider.convert(ek)
    }

    func deleteEvent(_ event: TimelineEvent) async throws {
        try ensureAuthorized(readOnly: false)
        guard let ek = store.calendarItem(withIdentifier: event.calendarItemIdentifier) as? EKEvent else {
            throw CalendarProviderError.eventNotFound(identifier: event.calendarItemIdentifier)
        }
        do {
            try store.remove(ek, span: .thisEvent, commit: true)
        } catch {
            throw CalendarProviderError.deleteFailed(underlying: error)
        }
    }

    // MARK: - Helpers

    private func ensureAuthorized(readOnly: Bool) throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            return
        case .writeOnly:
            if readOnly { throw CalendarProviderError.notAuthorized }
            return
        default:
            throw CalendarProviderError.notAuthorized
        }
    }

    private func validate(_ draft: EventDraft) throws {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { throw CalendarProviderError.invalidDraft(reason: "제목이 비어 있습니다.") }
        if draft.end <= draft.start && !draft.isAllDay {
            throw CalendarProviderError.invalidDraft(reason: "종료 시간이 시작보다 빠릅니다.")
        }
        if draft.calendarId.isEmpty {
            throw CalendarProviderError.invalidDraft(reason: "캘린더를 선택해 주세요.")
        }
    }

    private func apply(draft: EventDraft, to event: EKEvent, calendar: EKCalendar) {
        event.calendar = calendar
        event.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.notes = draft.notes.isEmpty ? nil : draft.notes
        event.location = draft.location.isEmpty ? nil : draft.location
        event.isAllDay = draft.isAllDay
        event.startDate = draft.start
        event.endDate = draft.end
    }

    static func convert(_ ek: EKEvent) -> TimelineEvent {
        let calId = ek.calendar?.calendarIdentifier ?? "unknown"
        let source = CalendarSource.apple(calendarId: calId)
        let identifier = ek.calendarItemIdentifier
        let occurrenceStart = ek.startDate ?? Date()
        let colorHex: String? = ek.calendar?.cgColor.flatMap { Self.hexString($0) }
        let attendees: [Attendee] = (ek.attendees ?? []).map { p in
            Attendee(
                name: p.name ?? "",
                email: Self.email(from: p.url),
                response: map(p.participantStatus),
                isOrganizer: false
            )
        }
        return TimelineEvent(
            source: source,
            calendarItemIdentifier: identifier,
            occurrenceStart: occurrenceStart,
            title: ek.title ?? "(제목 없음)",
            notes: ek.notes,
            location: ek.location,
            start: ek.startDate ?? Date(),
            end: ek.endDate ?? Date().addingTimeInterval(1800),
            isAllDay: ek.isAllDay,
            attendees: attendees,
            colorHex: colorHex,
            lastModified: ek.lastModifiedDate ?? Date(),
            url: ek.url
        )
    }

    private static func email(from url: URL?) -> String {
        guard let url else { return "" }
        return url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
    }

    private static func map(_ status: EKParticipantStatus) -> Attendee.ResponseStatus {
        switch status {
        case .accepted: return .accepted
        case .declined: return .declined
        case .tentative: return .tentative
        case .pending: return .needsAction
        default: return .unknown
        }
    }

    private static func hexString(_ cg: CGColor?) -> String? {
        guard let cg, let comps = cg.components, comps.count >= 3 else { return nil }
        let r = Int((comps[0] * 255).rounded())
        let g = Int((comps[1] * 255).rounded())
        let b = Int((comps[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
