import Combine
import Foundation

final class AppEnvironment: ObservableObject {
    let registry: ModuleRegistry
    let router: TabRouter

    init() {
        let registry = ModuleRegistry()
        registry.register(AnyEdgeModule(YouTubeModule()))
        self.registry = registry

        let router = TabRouter()
        if router.activeID == nil { router.activate("youtube") }
        self.router = router
    }
}
