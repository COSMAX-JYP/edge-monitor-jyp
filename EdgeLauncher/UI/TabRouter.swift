import Combine
import Foundation

final class TabRouter: ObservableObject {
    @Published var activeID: String? {
        didSet { defaults.set(activeID, forKey: Self.key) }
    }

    private let defaults: UserDefaults
    private static let key = "app.activeTab"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.activeID = defaults.string(forKey: Self.key)
    }

    func activate(_ id: String) {
        activeID = id
    }
}
