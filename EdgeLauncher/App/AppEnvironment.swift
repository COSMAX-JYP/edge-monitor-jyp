import Combine
import Foundation

final class AppEnvironment: ObservableObject {
    let registry: ModuleRegistry
    let router: TabRouter

    init() {
        self.registry = ModuleRegistry()
        self.router = TabRouter()
    }
}
