import Foundation

enum PermissionKind: String, CaseIterable, Sendable {
    case calendar
    case accessibility
    case automation
    case msal

    var displayName: String {
        switch self {
        case .calendar: return "캘린더"
        case .accessibility: return "손쉬운 사용"
        case .automation: return "자동화"
        case .msal: return "Microsoft 365"
        }
    }

    var systemSettingsURL: URL? {
        switch self {
        case .calendar:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .automation:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        case .msal:
            return nil
        }
    }
}
