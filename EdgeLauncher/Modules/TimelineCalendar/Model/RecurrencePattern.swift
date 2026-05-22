import Foundation

struct RecurrencePattern: Codable, Hashable, Sendable {
    var frequency: Frequency
    var interval: Int
    var daysOfWeek: [Weekday]
    var dayOfMonth: Int?
    var month: Int?
    var end: RecurrenceEnd

    init(
        frequency: Frequency,
        interval: Int = 1,
        daysOfWeek: [Weekday] = [],
        dayOfMonth: Int? = nil,
        month: Int? = nil,
        end: RecurrenceEnd = .never
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.daysOfWeek = daysOfWeek
        self.dayOfMonth = dayOfMonth
        self.month = month
        self.end = end
    }

    enum Frequency: String, Codable, Hashable, Sendable, CaseIterable {
        case daily, weekly, monthly, yearly
        var displayName: String {
            switch self {
            case .daily: return "매일"
            case .weekly: return "매주"
            case .monthly: return "매월"
            case .yearly: return "매년"
            }
        }
    }

    enum Weekday: String, Codable, Hashable, Sendable, CaseIterable {
        case sunday, monday, tuesday, wednesday, thursday, friday, saturday
        var displayName: String {
            switch self {
            case .sunday: return "일"
            case .monday: return "월"
            case .tuesday: return "화"
            case .wednesday: return "수"
            case .thursday: return "목"
            case .friday: return "금"
            case .saturday: return "토"
            }
        }
    }
}

enum RecurrenceEnd: Codable, Hashable, Sendable {
    case never
    case occurrences(Int)
    case onDate(Date)
}
