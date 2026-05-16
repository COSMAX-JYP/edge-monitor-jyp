import Foundation

struct Attendee: Codable, Hashable, Sendable {
    var name: String
    var email: String
    var response: ResponseStatus
    var isOrganizer: Bool

    enum ResponseStatus: String, Codable, Sendable {
        case accepted
        case tentative
        case declined
        case needsAction
        case unknown
    }
}
