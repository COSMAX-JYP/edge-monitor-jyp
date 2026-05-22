import Foundation

struct Attendee: Codable, Hashable, Sendable {
    var name: String
    var email: String
    var response: ResponseStatus
    var isOrganizer: Bool
    var type: AttendeeType

    init(
        name: String,
        email: String,
        response: ResponseStatus = .unknown,
        isOrganizer: Bool = false,
        type: AttendeeType = .required
    ) {
        self.name = name
        self.email = email
        self.response = response
        self.isOrganizer = isOrganizer
        self.type = type
    }

    enum ResponseStatus: String, Codable, Sendable {
        case accepted
        case tentative
        case declined
        case needsAction
        case unknown
    }

    enum AttendeeType: String, Codable, Hashable, Sendable, CaseIterable {
        case required
        case optional
        case resource

        var displayName: String {
            switch self {
            case .required: return "필수"
            case .optional: return "선택"
            case .resource: return "자원"
            }
        }
    }
}
