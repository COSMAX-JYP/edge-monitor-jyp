import Foundation

nonisolated enum IconType: String, Codable, Sendable, Hashable {
    case sfSymbol
    case emoji
}

nonisolated struct IconSpec: Codable, Hashable, Sendable {
    var type: IconType
    var value: String

    static let `default` = IconSpec(type: .sfSymbol, value: "square.grid.3x3.fill")
}
