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
        registry.register(AnyEdgeModule(SystemMonitorModule()))
        registry.register(AnyEdgeModule(WidgetDashboardModule()))
        registry.register(AnyEdgeModule(MessengerModule()))
        registry.register(AnyEdgeModule(LauncherModule()))
        registry.register(AnyEdgeModule(OutlookCalendarModule()))
        registry.register(AnyEdgeModule(NotionModule()))
        self.registry = registry

        let router = TabRouter()
        router.attach(registry: registry)
        if router.activeID == nil { router.activate("youtube") }
        self.router = router

        // DEBUG: 사이드바 빨간 배지 UI 자체가 동작하는지 검증
        BadgeStore.shared.set("messenger", count: 5)

        let displayService = XeneonDisplayService()
        self.displayService = displayService
        self.windowController = EdgeWindowController(displayService: displayService)
    }
}
