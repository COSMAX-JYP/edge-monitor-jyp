import Foundation

enum PermissionState: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case restricted
    case writeOnly
    case authorized

    var isUsable: Bool {
        switch self {
        case .authorized, .writeOnly: return true
        default: return false
        }
    }

    var needsUserAction: Bool {
        switch self {
        case .notDetermined, .denied, .restricted: return true
        default: return false
        }
    }
}
