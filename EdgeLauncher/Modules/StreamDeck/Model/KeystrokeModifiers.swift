import Foundation

nonisolated struct KeystrokeModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: Int

    static let command  = KeystrokeModifiers(rawValue: 1 << 0)
    static let option   = KeystrokeModifiers(rawValue: 1 << 1)
    static let control  = KeystrokeModifiers(rawValue: 1 << 2)
    static let shift    = KeystrokeModifiers(rawValue: 1 << 3)

    var symbol: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}
