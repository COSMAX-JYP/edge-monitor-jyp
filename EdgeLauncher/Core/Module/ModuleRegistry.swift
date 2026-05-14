import Combine
import SwiftUI

struct AnyEdgeModule: Identifiable {
    let id: String
    let title: String
    let iconName: String
    let supportsFullscreen: Bool
    let viewBuilder: () -> AnyView
    private let becameActive: () -> Void
    private let resigned: () -> Void

    init<M: EdgeModule>(_ module: M) {
        self.id = module.id
        self.title = module.title
        self.iconName = module.iconName
        self.supportsFullscreen = module.supportsFullscreen
        self.viewBuilder = { AnyView(module.view) }
        self.becameActive = { module.didBecomeActive() }
        self.resigned = { module.didResignActive() }
    }

    func didBecomeActive() { becameActive() }
    func didResignActive() { resigned() }
}

final class ModuleRegistry: ObservableObject {
    @Published private(set) var modules: [AnyEdgeModule] = []
    @Published private(set) var hiddenIDs: Set<String> = []

    private let orderKey = "app.moduleOrder"
    private let hiddenKey = "app.moduleHidden"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.array(forKey: hiddenKey) as? [String] {
            hiddenIDs = Set(stored)
        }
    }

    func register(_ module: AnyEdgeModule) {
        if let idx = modules.firstIndex(where: { $0.id == module.id }) {
            modules[idx] = module
        } else {
            modules.append(module)
        }
        applyStoredOrder()
    }

    func module(id: String) -> AnyEdgeModule? {
        modules.first { $0.id == id }
    }

    var visibleModules: [AnyEdgeModule] {
        modules.filter { !hiddenIDs.contains($0.id) }
    }

    func reorder(from: Int, to: Int) {
        guard from != to, from >= 0, from < modules.count, to >= 0, to <= modules.count else { return }
        let item = modules.remove(at: from)
        let insertAt = min(to, modules.count)
        modules.insert(item, at: insertAt)
        persistOrder()
    }

    func setVisible(_ id: String, visible: Bool) {
        if visible {
            hiddenIDs.remove(id)
        } else {
            hiddenIDs.insert(id)
        }
        defaults.set(Array(hiddenIDs), forKey: hiddenKey)
    }

    private func persistOrder() {
        defaults.set(modules.map(\.id), forKey: orderKey)
    }

    private func applyStoredOrder() {
        guard let order = defaults.array(forKey: orderKey) as? [String], !order.isEmpty else { return }
        let priority = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        modules.sort { (a, b) in
            (priority[a.id] ?? Int.max) < (priority[b.id] ?? Int.max)
        }
    }
}
