import Foundation

nonisolated enum IconType: String, Codable, Sendable, Hashable {
    case sfSymbol
    case emoji
    case image
}

nonisolated struct IconSpec: Codable, Hashable, Sendable {
    var type: IconType
    var value: String
    // Optional so older streamdeck.json files (which lack the key) keep decoding.
    var scale: Double?

    static let defaultScale: Double = 0.5
    static let minScale: Double = 0.32
    static let maxScale: Double = 0.88

    var effectiveScale: Double {
        let raw = scale ?? Self.defaultScale
        return min(max(raw, Self.minScale), Self.maxScale)
    }

    init(type: IconType, value: String, scale: Double? = nil) {
        self.type = type
        self.value = value
        self.scale = scale
    }

    static let `default` = IconSpec(type: .sfSymbol, value: "square.grid.3x3.fill")
}
