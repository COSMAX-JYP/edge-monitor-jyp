import Foundation
import Observation

@Observable
@MainActor
final class CalendarVisibilityStore {
    private let hiddenIdsKey = "app.timeline.hiddenCalendars"
    private let colorsKey = "app.timeline.calendarColors"

    private(set) var hiddenIds: Set<String>
    private(set) var customColors: [String: String]

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.array(forKey: hiddenIdsKey) as? [String] ?? []
        self.hiddenIds = Set(saved)
        if let dict = defaults.dictionary(forKey: colorsKey) as? [String: String] {
            self.customColors = dict
        } else {
            self.customColors = [:]
        }
    }

    func isVisible(_ id: String) -> Bool {
        !hiddenIds.contains(id)
    }

    func toggle(_ id: String) {
        if hiddenIds.contains(id) {
            hiddenIds.remove(id)
        } else {
            hiddenIds.insert(id)
        }
        persist()
    }

    func setVisible(_ id: String, visible: Bool) {
        if visible { hiddenIds.remove(id) } else { hiddenIds.insert(id) }
        persist()
    }

    /// No-op kept for backward compatibility; new calendars are visible by default.
    func initializeIfNeeded(with allIds: [String]) {}

    func color(for id: String) -> String? {
        customColors[id]
    }

    func setColor(_ id: String, hex: String?) {
        if let hex { customColors[id] = hex } else { customColors.removeValue(forKey: id) }
        defaults.set(customColors, forKey: colorsKey)
    }

    private func persist() {
        defaults.set(Array(hiddenIds), forKey: hiddenIdsKey)
    }
}
