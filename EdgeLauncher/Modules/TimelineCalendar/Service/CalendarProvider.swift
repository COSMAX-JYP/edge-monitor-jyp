import Foundation

nonisolated struct EventDraft: Hashable, Sendable {
    var title: String
    var notes: String
    var location: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var calendarId: String

    init(
        title: String = "",
        notes: String = "",
        location: String = "",
        start: Date = Date(),
        end: Date = Date().addingTimeInterval(3600),
        isAllDay: Bool = false,
        calendarId: String = ""
    ) {
        self.title = title
        self.notes = notes
        self.location = location
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarId = calendarId
    }
}

nonisolated struct CalendarChoice: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var sourceTitle: String
    var colorHex: String?
    var allowsModifications: Bool
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
