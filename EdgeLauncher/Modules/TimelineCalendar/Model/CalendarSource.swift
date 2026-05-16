import Foundation

enum CalendarSource: Codable, Hashable, Sendable {
    case apple(calendarId: String)
    case outlook(calendarId: String, tenantId: String)
    case local(boardId: String)

    var key: String {
        switch self {
        case .apple(let id): return "apple:\(id)"
        case .outlook(let id, let tenant): return "outlook:\(tenant):\(id)"
        case .local(let id): return "local:\(id)"
        }
    }

    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .outlook: return "Outlook"
        case .local: return "Local"
        }
    }
}
