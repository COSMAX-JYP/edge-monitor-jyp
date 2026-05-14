import Combine
import SwiftUI

struct AnyEdgeModule: Identifiable {
    let id: String
    let title: String
    let iconName: String
    let supportsFullscreen: Bool
    let viewBuilder: () -> AnyView

    init<M: EdgeModule>(_ module: M) {
        self.id = module.id
        self.title = module.title
        self.iconName = module.iconName
        self.supportsFullscreen = module.supportsFullscreen
        self.viewBuilder = { AnyView(module.view) }
    }
}

final class ModuleRegistry: ObservableObject {
    @Published private(set) var modules: [AnyEdgeModule] = []

    func register(_ module: AnyEdgeModule) {
        if let idx = modules.firstIndex(where: { $0.id == module.id }) {
            modules[idx] = module
        } else {
            modules.append(module)
        }
    }

    func module(id: String) -> AnyEdgeModule? {
        modules.first { $0.id == id }
    }
}
