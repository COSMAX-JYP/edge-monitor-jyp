import Foundation

nonisolated struct StreamDeckButton: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var position: GridPosition
    var label: String
    var icon: IconSpec
    var backgroundHex: String
    var foregroundHex: String
    // Optional so older streamdeck.json files (which lack these keys) keep decoding.
    // nil means "inherit from foregroundHex / use system default".
    var labelColorHex: String?
    var labelFontName: String?
    var action: StreamDeckAction
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        position: GridPosition,
        label: String = "",
        icon: IconSpec = .default,
        backgroundHex: String = "#2C2C2E",
        foregroundHex: String = "#FFFFFF",
        labelColorHex: String? = nil,
        labelFontName: String? = nil,
        action: StreamDeckAction = .none,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.position = position
        self.label = label
        self.icon = icon
        self.backgroundHex = backgroundHex
        self.foregroundHex = foregroundHex
        self.labelColorHex = labelColorHex
        self.labelFontName = labelFontName
        self.action = action
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
