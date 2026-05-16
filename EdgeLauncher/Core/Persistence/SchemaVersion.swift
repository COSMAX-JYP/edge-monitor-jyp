import Foundation

protocol Versioned {
    nonisolated static var schemaVersion: Int { get }
}

struct VersionedEnvelope<T: Codable & Versioned>: Codable {
    let schemaVersion: Int
    let payload: T

    init(payload: T) {
        self.schemaVersion = T.schemaVersion
        self.payload = payload
    }
}

enum SchemaMigrationError: Error {
    case unsupportedVersion(Int, supported: Int)
    case payloadDecodeFailure(Error)
}
