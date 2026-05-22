import Foundation

enum TimelineViewMode: String, CaseIterable, Codable, Sendable {
    case day
    case week
    case month

    var displayName: String {
        switch self {
        case .day: return "일간"
        case .week: return "주간"
        case .month: return "월간"
        }
    }
}
