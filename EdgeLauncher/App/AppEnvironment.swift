import Combine
import EventKit
import Foundation
import os

@MainActor
final class AppEnvironment: ObservableObject {
    let registry: ModuleRegistry
    let router: TabRouter
    let displayService: XeneonDisplayService
    let windowController: EdgeWindowController
    let cursorGuard: EdgeCursorGuard
    let hidCapture: CorsairHIDCapture
    let commandRouter: CommandRouter
    let permissionService: PermissionService
    let eventStore: EKEventStore
    let msalAuth: MSALAuthService?
    let kanbanStore: KanbanStore
    private var didBootstrapWindow = false
    private var edgeMoveObserver: NSObjectProtocol?

    init() {
        let registry = ModuleRegistry()
        registry.register(AnyEdgeModule(YouTubeModule()))
        registry.register(AnyEdgeModule(YouTubeMusicModule()))
        registry.register(AnyEdgeModule(SystemMonitorModule()))
        registry.register(AnyEdgeModule(WidgetDashboardModule()))
        for cfg in MessengerInstanceConfig.allInstances {
            registry.register(AnyEdgeModule(MessengerModule(config: cfg)))
        }
        registry.register(AnyEdgeModule(LauncherModule()))
        registry.register(AnyEdgeModule(BrowserModule()))
        registry.register(AnyEdgeModule(OutlookCalendarModule()))
        registry.register(AnyEdgeModule(NotionModule()))
        self.registry = registry

        let router = TabRouter()
        router.attach(registry: registry)
        self.router = router

        self.commandRouter = CommandRouter.shared

        let sharedStore = EKEventStore()
        self.eventStore = sharedStore

        let permissionService = PermissionService(probes: [
            CalendarPermissionProbe(store: sharedStore),
            AccessibilityPermissionProbe()
        ])
        self.permissionService = permissionService

        let msalAuth: MSALAuthService?
        do {
            msalAuth = try MSALAuthService()
        } catch {
            AppLog.app.error("MSAL init failed: \(String(describing: error))")
            msalAuth = nil
        }
        self.msalAuth = msalAuth

        registry.register(AnyEdgeModule(TimelineCalendarModule(
            permissionService: permissionService,
            eventStore: sharedStore,
            msalAuth: msalAuth
        )))
        let kanbanStore = KanbanStore()
        self.kanbanStore = kanbanStore
        registry.register(AnyEdgeModule(KanbanModule(store: kanbanStore)))
        registry.register(AnyEdgeModule(StreamDeckModule(permissionService: permissionService)))
        registry.register(AnyEdgeModule(LockScreenModule()))
        registry.register(AnyEdgeModule(MeetingRecorderModule()))

        let modules = registry.modules
        commandRouter.setGlobalDefault(.refresh) { [weak router, modules] in
            guard let activeID = router?.activeID else { return }
            if let _ = modules.first(where: { $0.id == activeID }) {
                NotificationCenter.default.post(name: .moduleRefreshRequested, object: nil, userInfo: ["moduleID": activeID])
            }
        }
        for (index, module) in modules.prefix(9).enumerated() {
            guard let slot = ModuleCommand.slot(at: index) else { continue }
            let moduleID = module.id
            commandRouter.setGlobalDefault(slot) { [weak router] in
                router?.activate(moduleID)
            }
        }

        if router.activeID == nil { router.activate("youtube") }

        let displayService = XeneonDisplayService()
        self.displayService = displayService
        self.windowController = EdgeWindowController(displayService: displayService)
        self.cursorGuard = EdgeCursorGuard(displayService: displayService)
        self.hidCapture = CorsairHIDCapture(displayService: displayService)
    }

    deinit {
        if let edgeMoveObserver {
            NotificationCenter.default.removeObserver(edgeMoveObserver)
        }
    }

    @discardableResult
    func bootstrapWindowIfNeeded() -> Bool {
        guard !didBootstrapWindow else { return false }
        didBootstrapWindow = true

        edgeMoveObserver = NotificationCenter.default.addObserver(
            forName: .edgeMoveRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.windowController.moveMainWindowToEdge()
            }
        }

        cursorGuard.installEventMonitor()
        hidCapture.start()
        return true
    }
}

extension Notification.Name {
    static let moduleRefreshRequested = Notification.Name("EdgeLauncher.moduleRefreshRequested")
}
