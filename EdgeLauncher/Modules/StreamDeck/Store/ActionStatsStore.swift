import Foundation
import Observation

@Observable
@MainActor
final class ActionStatsStore {
    @ObservationIgnored
    private let backing: AtomicJSONStore<ActionStatsData>

    var data: ActionStatsData { backing.value }

    init(url: URL? = nil) {
        let location = url ?? ActionStatsStore.defaultURL()
        self.backing = AtomicJSONStore<ActionStatsData>(
            url: location,
            default: ActionStatsData.makeDefault()
        )
    }

    static func defaultURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("EdgeLauncher", isDirectory: true)
            .appendingPathComponent("streamdeck-stats.json")
    }

    func flush() async throws {
        try await backing.flush()
    }

    func entry(for buttonId: UUID) -> ActionStatsEntry {
        data.entries[buttonId] ?? ActionStatsEntry(buttonId: buttonId)
    }

    func recordTap(_ buttonId: UUID) {
        backing.update { data in
            var entry = data.entries[buttonId] ?? ActionStatsEntry(buttonId: buttonId)
            entry.tapCount += 1
            entry.lastTappedAt = Date()
            data.entries[buttonId] = entry
        }
    }

    func recordSuccess(_ buttonId: UUID, duration: Double) {
        backing.update { data in
            var entry = data.entries[buttonId] ?? ActionStatsEntry(buttonId: buttonId)
            entry.successCount += 1
            entry.lastSucceededAt = Date()
            entry.totalDurationSeconds += duration
            data.entries[buttonId] = entry
        }
    }

    func recordError(_ buttonId: UUID, message: String) {
        backing.update { data in
            var entry = data.entries[buttonId] ?? ActionStatsEntry(buttonId: buttonId)
            entry.errorCount += 1
            entry.lastFailedAt = Date()
            entry.lastError = message
            data.entries[buttonId] = entry
        }
    }

    func remove(_ buttonId: UUID) {
        backing.update { data in
            data.entries.removeValue(forKey: buttonId)
        }
    }

    func reset() {
        backing.replace(ActionStatsData.makeDefault())
    }

    func topUsed(limit: Int = 20) -> [ActionStatsEntry] {
        data.entries.values.sorted { $0.tapCount > $1.tapCount }.prefix(limit).map { $0 }
    }
}
