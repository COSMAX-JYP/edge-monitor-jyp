import Foundation

nonisolated struct EventDraft: Hashable, Sendable {
    var title: String
    var notes: String
    var location: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var calendarId: String
    var attendees: [Attendee]
    var isOnlineMeeting: Bool
    var responseRequested: Bool
    var allowNewTimeProposals: Bool
    var reminderMinutesBeforeStart: Int?
    var importance: EventImportance
    var sensitivity: EventSensitivity
    var showAs: EventShowAs
    var categories: [String]
    var recurrence: RecurrencePattern?

    init(
        title: String = "",
        notes: String = "",
        location: String = "",
        start: Date = Date(),
        end: Date = Date().addingTimeInterval(3600),
        isAllDay: Bool = false,
        calendarId: String = "",
        attendees: [Attendee] = [],
        isOnlineMeeting: Bool = false,
        responseRequested: Bool = true,
        allowNewTimeProposals: Bool = true,
        reminderMinutesBeforeStart: Int? = 15,
        importance: EventImportance = .normal,
        sensitivity: EventSensitivity = .normal,
        showAs: EventShowAs = .busy,
        categories: [String] = [],
        recurrence: RecurrencePattern? = nil
    ) {
        self.title = title
        self.notes = notes
        self.location = location
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarId = calendarId
        self.attendees = attendees
        self.isOnlineMeeting = isOnlineMeeting
        self.responseRequested = responseRequested
        self.allowNewTimeProposals = allowNewTimeProposals
        self.reminderMinutesBeforeStart = reminderMinutesBeforeStart
        self.importance = importance
        self.sensitivity = sensitivity
        self.showAs = showAs
        self.categories = categories
        self.recurrence = recurrence
    }
}

enum EventImportance: String, Codable, Hashable, Sendable, CaseIterable {
    case low, normal, high
    var displayName: String {
        switch self {
        case .low: return "낮음"
        case .normal: return "일반"
        case .high: return "높음"
        }
    }
}

enum EventSensitivity: String, Codable, Hashable, Sendable, CaseIterable {
    case normal, personal, `private`, confidential
    var displayName: String {
        switch self {
        case .normal: return "일반"
        case .personal: return "개인"
        case .private: return "비공개"
        case .confidential: return "기밀"
        }
    }
}

enum EventShowAs: String, Codable, Hashable, Sendable, CaseIterable {
    case free, tentative, busy, oof, workingElsewhere
    var displayName: String {
        switch self {
        case .free: return "여유"
        case .tentative: return "잠정"
        case .busy: return "바쁨"
        case .oof: return "부재중"
        case .workingElsewhere: return "외부 근무"
        }
    }
}

nonisolated struct CalendarChoice: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var sourceTitle: String
    var colorHex: String?
    var allowsModifications: Bool
    var providerKind: CalendarSourceKind

    init(
        id: String,
        title: String,
        sourceTitle: String,
        colorHex: String? = nil,
        allowsModifications: Bool = true,
        providerKind: CalendarSourceKind = .apple
    ) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
        self.colorHex = colorHex
        self.allowsModifications = allowsModifications
        self.providerKind = providerKind
    }
}

@MainActor
protocol CalendarProvider: AnyObject {
    var source: CalendarSourceKind { get }
    func fetchEvents(on day: Date) async throws -> [TimelineEvent]
    func availableCalendars() async throws -> [CalendarChoice]
    func defaultCalendarId() async throws -> String?
    func saveEvent(_ draft: EventDraft) async throws -> TimelineEvent
    func updateEvent(_ event: TimelineEvent, draft: EventDraft) async throws -> TimelineEvent
    func deleteEvent(_ event: TimelineEvent) async throws
}

enum CalendarSourceKind: String, Sendable {
    case apple
    case outlook
    case local
}

enum CalendarProviderError: Error, LocalizedError {
    case notAuthorized
    case fetchFailed(underlying: Error)
    case unsupported
    case eventNotFound(identifier: String)
    case calendarNotFound(identifier: String)
    case readOnlyCalendar
    case invalidDraft(reason: String)
    case saveFailed(underlying: Error)
    case deleteFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "캘린더 접근 권한이 없습니다."
        case .fetchFailed(let e): return "캘린더 조회 실패: \(e.localizedDescription)"
        case .unsupported: return "이 캘린더는 지원하지 않는 동작입니다."
        case .eventNotFound(let id): return "일정을 찾을 수 없습니다: \(id)"
        case .calendarNotFound(let id): return "캘린더를 찾을 수 없습니다: \(id)"
        case .readOnlyCalendar: return "이 캘린더는 쓰기를 허용하지 않습니다."
        case .invalidDraft(let reason): return "입력 오류: \(reason)"
        case .saveFailed(let e): return "저장 실패: \(e.localizedDescription)"
        case .deleteFailed(let e): return "삭제 실패: \(e.localizedDescription)"
        }
    }
}
