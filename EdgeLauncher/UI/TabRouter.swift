import Combine
import Foundation

final class TabRouter: ObservableObject {
    @Published private(set) var activeID: String? {
        didSet { defaults.set(activeID, forKey: Self.key) }
    }

    private let defaults: UserDefaults
    private static let key = "app.activeTab"
    private(set) weak var registry: ModuleRegistry?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.activeID = defaults.string(forKey: Self.key)
    }

    func attach(registry: ModuleRegistry) {
        self.registry = registry
    }

    func activate(_ id: String) {
        guard id != activeID else { return }
        let previousID = activeID
        activeID = id
        if let previousID, let prev = registry?.module(id: previousID) {
            prev.didResignActive()
        }
        if let next = registry?.module(id: id) {
            next.didBecomeActive()
        }
    }
}
