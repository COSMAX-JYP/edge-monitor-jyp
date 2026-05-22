import Foundation
import os

@MainActor
final class GraphCalendarProvider: CalendarProvider {
    let source: CalendarSourceKind = .outlook

    private let auth: MSALAuthService
    private let session: URLSession
    private let tenantId: String

    init(auth: MSALAuthService, session: URLSession = .shared, tenantId: String? = nil) {
        self.auth = auth
        self.session = session
        self.tenantId = tenantId ?? OutlookConfig.tenantId
    }

    func fetchEvents(on day: Date) async throws -> [TimelineEvent] {
        let signedIn = auth.isSignedIn()
        AppLog.event.info("Graph fetchEvents signedIn=\(signedIn, privacy: .public)")
        guard signedIn else { return [] }
        let token = try await acquireToken()
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        var comps = URLComponents(string: "\(OutlookConfig.graphBase)/me/calendarView")!
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        comps.queryItems = [
            .init(name: "startDateTime", value: iso.string(from: dayStart)),
            .init(name: "endDateTime", value: iso.string(from: dayEnd)),
            .init(name: "$select", value: "id,subject,bodyPreview,location,start,end,isAllDay,attendees,onlineMeetingUrl,webLink,organizer,lastModifiedDateTime,categories,importance,sensitivity,showAs,recurrence,seriesMasterId,type,isOrganizer"),
            .init(name: "$orderby", value: "start/dateTime"),
            .init(name: "$top", value: "250")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("outlook.timezone=\"\(TimeZone.current.identifier)\"", forHTTPHeaderField: "Prefer")
        let urlStr = comps.url?.absoluteString ?? "?"
        AppLog.event.info("Graph GET \(urlStr, privacy: .public)")

        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.event.info("Graph response status=\(status, privacy: .public) bytes=\(data.count, privacy: .public)")
        if status >= 400 {
            let body = String(data: data.prefix(800), encoding: .utf8) ?? ""
            AppLog.event.error("Graph error body: \(body, privacy: .public)")
        }
        try Self.validate(response: response, data: data)
        let decoded = try Self.decode(GraphCalendarViewResponse.self, from: data)
        AppLog.event.info("Graph decoded \(decoded.value.count, privacy: .public) events")
        return decoded.value.map { ev in Self.convert(ev, tenantId: tenantId) }
    }

    func availableCalendars() async throws -> [CalendarChoice] {
        guard auth.isSignedIn() else { return [] }
        let token = try await acquireToken()
        var req = URLRequest(url: URL(string: "\(OutlookConfig.graphBase)/me/calendars?$select=id,name,canEdit,owner,color,hexColor")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: req)
        try Self.validate(response: response, data: data)
        let decoded = try Self.decode(GraphCalendarListResponse.self, from: data)
        return decoded.value.map { c in
            CalendarChoice(
                id: c.id,
                title: c.name,
                sourceTitle: c.owner?.name ?? "Outlook",
                colorHex: c.hexColor,
                allowsModifications: c.canEdit ?? false,
                providerKind: .outlook
            )
        }
    }

    func defaultCalendarId() async throws -> String? {
        guard auth.isSignedIn() else { return nil }
        let token = try await acquireToken()
        var req = URLRequest(url: URL(string: "\(OutlookConfig.graphBase)/me/calendar?$select=id")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: req)
        try Self.validate(response: response, data: data)
        let decoded = try Self.decode(GraphCalendar.self, from: data)
        return decoded.id
    }

    func saveEvent(_ draft: EventDraft) async throws -> TimelineEvent {
        guard auth.isSignedIn() else { throw CalendarProviderError.notAuthorized }
        try validate(draft)
        let token = try await acquireToken()
        let endpoint = draft.calendarId.isEmpty
            ? "\(OutlookConfig.graphBase)/me/events"
            : "\(OutlookConfig.graphBase)/me/calendars/\(draft.calendarId)/events"
        var req = URLRequest(url: URL(string: endpoint)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try Self.encode(graphBody(from: draft))

        let (data, response) = try await session.data(for: req)
        try Self.validate(response: response, data: data)
        let decoded = try Self.decode(GraphEvent.self, from: data)
        return Self.convert(decoded, tenantId: tenantId)
    }

    func updateEvent(_ event: TimelineEvent, draft: EventDraft) async throws -> TimelineEvent {
        guard auth.isSignedIn() else { throw CalendarProviderError.notAuthorized }
        try validate(draft)
        let token = try await acquireToken()
        var req = URLRequest(url: URL(string: "\(OutlookConfig.graphBase)/me/events/\(event.calendarItemIdentifier)")!)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try Self.encode(graphBody(from: draft))

        let (data, response) = try await session.data(for: req)
        try Self.validate(response: response, data: data)
        let decoded = try Self.decode(GraphEvent.self, from: data)
        return Self.convert(decoded, tenantId: tenantId)
    }

    func deleteEvent(_ event: TimelineEvent) async throws {
        guard auth.isSignedIn() else { throw CalendarProviderError.notAuthorized }
        let token = try await acquireToken()
        var req = URLRequest(url: URL(string: "\(OutlookConfig.graphBase)/me/events/\(event.calendarItemIdentifier)")!)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: req)
        try Self.validate(response: response, data: data)
    }

    // MARK: - Helpers

    private func acquireToken() async throws -> String {
        let res = try await auth.acquireAccessToken()
        return res.accessToken
    }

    private func validate(_ draft: EventDraft) throws {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { throw CalendarProviderError.invalidDraft(reason: "제목이 비어 있습니다.") }
        if draft.end <= draft.start && !draft.isAllDay {
            throw CalendarProviderError.invalidDraft(reason: "종료 시간이 시작보다 빠릅니다.")
        }
    }

    private func graphBody(from draft: EventDraft) -> GraphEventInput {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let tz = TimeZone.current.identifier
        let attendees = draft.attendees.map { att in
            GraphAttendeeInput(
                emailAddress: GraphEmailAddress(name: att.name.isEmpty ? nil : att.name, address: att.email),
                type: att.type.rawValue
            )
        }
        return GraphEventInput(
            subject: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: draft.notes.isEmpty ? nil : .init(contentType: "text", content: draft.notes),
            start: .init(dateTime: iso.string(from: draft.start), timeZone: tz),
            end: .init(dateTime: iso.string(from: draft.end), timeZone: tz),
            location: draft.location.isEmpty ? nil : .init(displayName: draft.location),
            isAllDay: draft.isAllDay,
            attendees: attendees.isEmpty ? nil : attendees,
            isOnlineMeeting: draft.isOnlineMeeting ? true : nil,
            onlineMeetingProvider: draft.isOnlineMeeting ? "teamsForBusiness" : nil,
            responseRequested: draft.responseRequested,
            allowNewTimeProposals: draft.allowNewTimeProposals,
            reminderMinutesBeforeStart: draft.reminderMinutesBeforeStart,
            isReminderOn: draft.reminderMinutesBeforeStart != nil,
            importance: draft.importance.rawValue,
            sensitivity: draft.sensitivity.rawValue,
            showAs: draft.showAs.rawValue,
            categories: draft.categories.isEmpty ? nil : draft.categories,
            recurrence: Self.graphRecurrence(from: draft.recurrence, startDate: draft.start)
        )
    }

    private static func graphRecurrence(from pattern: RecurrencePattern?, startDate: Date) -> GraphRecurrenceInput? {
        guard let p = pattern else { return nil }
        let cal = Calendar.current
        let startStr = ISO8601DateFormatter.dateOnly(startDate)
        let patternBody: GraphRecurrencePatternInput
        switch p.frequency {
        case .daily:
            patternBody = GraphRecurrencePatternInput(type: "daily", interval: p.interval, daysOfWeek: nil, dayOfMonth: nil, month: nil, firstDayOfWeek: "sunday")
        case .weekly:
            let days = p.daysOfWeek.isEmpty ? [Weekday(rawValue: weekdayString(cal.component(.weekday, from: startDate))) ?? .monday] : p.daysOfWeek.map { Weekday(rawValue: $0.rawValue)! }
            patternBody = GraphRecurrencePatternInput(type: "weekly", interval: p.interval, daysOfWeek: days.map { $0.rawValue }, dayOfMonth: nil, month: nil, firstDayOfWeek: "sunday")
        case .monthly:
            patternBody = GraphRecurrencePatternInput(type: "absoluteMonthly", interval: p.interval, daysOfWeek: nil, dayOfMonth: p.dayOfMonth ?? cal.component(.day, from: startDate), month: nil, firstDayOfWeek: nil)
        case .yearly:
            patternBody = GraphRecurrencePatternInput(type: "absoluteYearly", interval: p.interval, daysOfWeek: nil, dayOfMonth: p.dayOfMonth ?? cal.component(.day, from: startDate), month: p.month ?? cal.component(.month, from: startDate), firstDayOfWeek: nil)
        }
        let rangeBody: GraphRecurrenceRangeInput
        switch p.end {
        case .never:
            rangeBody = GraphRecurrenceRangeInput(type: "noEnd", startDate: startStr, endDate: nil, numberOfOccurrences: nil)
        case .occurrences(let n):
            rangeBody = GraphRecurrenceRangeInput(type: "numbered", startDate: startStr, endDate: nil, numberOfOccurrences: n)
        case .onDate(let d):
            rangeBody = GraphRecurrenceRangeInput(type: "endDate", startDate: startStr, endDate: ISO8601DateFormatter.dateOnly(d), numberOfOccurrences: nil)
        }
        return GraphRecurrenceInput(pattern: patternBody, range: rangeBody)
    }

    typealias Weekday = RecurrencePattern.Weekday

    private static func weekdayString(_ weekday: Int) -> String {
        // Calendar.weekday: 1=Sunday … 7=Saturday
        let names = ["", "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        return names[max(1, min(7, weekday))]
    }

    // MARK: - Response actions

    func respondToEvent(_ event: TimelineEvent, response: ResponseAction, comment: String?, sendResponse: Bool) async throws {
        guard auth.isSignedIn() else { throw CalendarProviderError.notAuthorized }
        let token = try await acquireToken()
        let endpoint: String
        switch response {
        case .accept: endpoint = "accept"
        case .tentative: endpoint = "tentativelyAccept"
        case .decline: endpoint = "decline"
        }
        var req = URLRequest(url: URL(string: "\(OutlookConfig.graphBase)/me/events/\(event.calendarItemIdentifier)/\(endpoint)")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["sendResponse": sendResponse]
        if let comment, !comment.isEmpty { body["comment"] = comment }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, urlResponse) = try await session.data(for: req)
        try Self.validate(response: urlResponse, data: data)
    }

    enum ResponseAction { case accept, tentative, decline }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CalendarProviderError.fetchFailed(underlying: URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            let message = "Graph HTTP \(http.statusCode): \(bodyString.prefix(400))"
            throw CalendarProviderError.fetchFailed(underlying: NSError(
                domain: "GraphAPI",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    private static func convert(_ ev: GraphEvent, tenantId: String) -> TimelineEvent {
        let calId = ev.calendar?.id ?? ev.calendarId ?? "default"
        let calHex = ev.calendar?.hexColor
        let start = parseGraphDate(ev.start)
        let end = parseGraphDate(ev.end)
        let attendees: [Attendee] = (ev.attendees ?? []).map { p in
            Attendee(
                name: p.emailAddress?.name ?? "",
                email: p.emailAddress?.address ?? "",
                response: Self.mapResponse(p.status?.response),
                isOrganizer: false
            )
        }
        let url: URL? = {
            if let meet = ev.onlineMeetingUrl, let u = URL(string: meet) { return u }
            if let web = ev.webLink, let u = URL(string: web) { return u }
            return nil
        }()
        return TimelineEvent(
            source: .outlook(calendarId: calId, tenantId: tenantId),
            calendarItemIdentifier: ev.id,
            occurrenceStart: start,
            title: ev.subject ?? "(제목 없음)",
            notes: ev.bodyPreview,
            location: ev.location?.displayName,
            start: start,
            end: end,
            isAllDay: ev.isAllDay ?? false,
            attendees: attendees,
            colorHex: calHex,
            lastModified: ev.lastModifiedDateTime ?? Date(),
            url: url,
            isOrganizer: ev.isOrganizer ?? false
        )
    }

    private static func parseGraphDate(_ dt: GraphDateTime?) -> Date {
        guard let dt else { return Date() }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = iso.date(from: dt.dateTime) { return parsed }
        iso.formatOptions = [.withInternetDateTime]
        if let parsed = iso.date(from: dt.dateTime) { return parsed }
        // Graph sometimes returns "2026-05-21T09:00:00.0000000" without TZ
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: dt.timeZone) ?? .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
        return formatter.date(from: dt.dateTime) ?? Date()
    }

    private static func mapResponse(_ s: String?) -> Attendee.ResponseStatus {
        switch s {
        case "accepted": return .accepted
        case "declined": return .declined
        case "tentativelyAccepted": return .tentative
        case "notResponded": return .needsAction
        default: return .unknown
        }
    }
}

// MARK: - Graph DTOs

private struct GraphCalendarViewResponse: Decodable {
    let value: [GraphEvent]
}

private struct GraphCalendarListResponse: Decodable {
    let value: [GraphCalendar]
}

private struct GraphCalendar: Decodable {
    let id: String
    let name: String
    let canEdit: Bool?
    let owner: GraphOwner?
    let color: String?
    let hexColor: String?
}

private struct GraphOwner: Decodable {
    let name: String?
    let address: String?
}

private struct GraphEvent: Decodable {
    let id: String
    let calendarId: String?
    let calendar: GraphEventCalendarRef?
    let subject: String?
    let bodyPreview: String?
    let location: GraphLocation?
    let start: GraphDateTime?
    let end: GraphDateTime?
    let isAllDay: Bool?
    let attendees: [GraphAttendee]?
    let onlineMeetingUrl: String?
    let webLink: String?
    let organizer: GraphAttendee?
    let lastModifiedDateTime: Date?
    let isOrganizer: Bool?
}

private struct GraphEventCalendarRef: Decodable {
    let id: String?
    let hexColor: String?
}

private struct GraphLocation: Codable {
    let displayName: String?
}

private struct GraphDateTime: Codable {
    let dateTime: String
    let timeZone: String
}

private struct GraphAttendee: Decodable {
    let emailAddress: GraphEmailAddress?
    let status: GraphAttendeeStatus?
}

private struct GraphEmailAddress: Codable {
    let name: String?
    let address: String?
}

private struct GraphAttendeeStatus: Decodable {
    let response: String?
}

private struct GraphEventInput: Encodable {
    let subject: String
    let body: GraphEventBody?
    let start: GraphDateTime
    let end: GraphDateTime
    let location: GraphLocation?
    let isAllDay: Bool
    let attendees: [GraphAttendeeInput]?
    let isOnlineMeeting: Bool?
    let onlineMeetingProvider: String?
    let responseRequested: Bool?
    let allowNewTimeProposals: Bool?
    let reminderMinutesBeforeStart: Int?
    let isReminderOn: Bool?
    let importance: String?
    let sensitivity: String?
    let showAs: String?
    let categories: [String]?
    let recurrence: GraphRecurrenceInput?
}

private struct GraphEventBody: Encodable {
    let contentType: String
    let content: String
}

private struct GraphAttendeeInput: Encodable {
    let emailAddress: GraphEmailAddress
    let type: String
}

private struct GraphRecurrenceInput: Encodable {
    let pattern: GraphRecurrencePatternInput
    let range: GraphRecurrenceRangeInput
}

private struct GraphRecurrencePatternInput: Encodable {
    let type: String
    let interval: Int
    let daysOfWeek: [String]?
    let dayOfMonth: Int?
    let month: Int?
    let firstDayOfWeek: String?
}

private struct GraphRecurrenceRangeInput: Encodable {
    let type: String
    let startDate: String?
    let endDate: String?
    let numberOfOccurrences: Int?
}

private extension ISO8601DateFormatter {
    static func dateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
