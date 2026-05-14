import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let registry: ModuleRegistry
    let router: TabRouter
    let displayService: XeneonDisplayService
    let windowController: EdgeWindowController

    init() {
        let registry = ModuleRegistry()
        registry.register(AnyEdgeModule(YouTubeModule()))
        registry.register(AnyEdgeModule(YouTubeMusicModule()))
        self.registry = registry

        let router = TabRouter()
        if router.activeID == nil { router.activate("youtube") }
        self.router = router

        let displayService = XeneonDisplayService()
        self.displayService = displayService
        self.windowController = EdgeWindowController(displayService: displayService)
    }
}
