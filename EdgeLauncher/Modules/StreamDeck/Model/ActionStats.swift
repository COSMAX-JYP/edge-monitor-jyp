import Foundation

nonisolated struct ActionStatsEntry: Codable, Hashable, Sendable {
    var buttonId: UUID
    var tapCount: Int
    var successCount: Int
    var errorCount: Int
    var lastTappedAt: Date?
    var lastSucceededAt: Date?
    var lastFailedAt: Date?
    var lastError: String?
    var totalDurationSeconds: Double

    init(
        buttonId: UUID,
        tapCount: Int = 0,
        successCount: Int = 0,
        errorCount: Int = 0,
        lastTappedAt: Date? = nil,
        lastSucceededAt: Date? = nil,
        lastFailedAt: Date? = nil,
        lastError: String? = nil,
        totalDurationSeconds: Double = 0
    ) {
        self.buttonId = buttonId
        self.tapCount = tapCount
        self.successCount = successCount
        self.errorCount = errorCount
        self.lastTappedAt = lastTappedAt
        self.lastSucceededAt = lastSucceededAt
        self.lastFailedAt = lastFailedAt
        self.lastError = lastError
        self.totalDurationSeconds = totalDurationSeconds
    }

    var successRate: Double {
        guard tapCount > 0 else { return 0 }
        return Double(successCount) / Double(tapCount)
    }

    var averageDuration: Double {
        guard successCount > 0 else { return 0 }
        return totalDurationSeconds / Double(successCount)
    }
}

nonisolated struct ActionStatsData: Codable, Versioned, Sendable {
    static var schemaVersion: Int { 1 }
    var entries: [UUID: ActionStatsEntry]

    static func makeDefault() -> ActionStatsData {
        ActionStatsData(entries: [:])
    }
}
