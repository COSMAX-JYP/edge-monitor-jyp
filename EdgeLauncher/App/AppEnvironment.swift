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
    let slidePanelSettings: KanbanSlidePanelSettings
    let slidePanelHotKey: KanbanSlidePanelHotKey
    let slidePanelController: KanbanSlidePanelController
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
        registry.register(AnyEdgeModule(BrowserModule()))
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

        let panelSettings = KanbanSlidePanelSettings()
        self.slidePanelSettings = panelSettings
        self.slidePanelController = KanbanSlidePanelController(store: kanbanStore, settings: panelSettings)
        self.slidePanelHotKey = KanbanSlidePanelHotKey()
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

    private func rebindSlidePanelHotKey() {
        do {
            try slidePanelHotKey.bind(
                keyCode: slidePanelSettings.hotKeyCode,
                modifiers: slidePanelSettings.hotKeyModifiers
            ) { [weak slidePanelController] in slidePanelController?.toggle() }
        } catch {
            AppLog.app.error("SlidePad hotkey bind failed: \(String(describing: error))")
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

        // SlidePad 단축키 등록 + 패널 wake-up. v2.1: 핫키 실패 시 View 메뉴 fallback (Task 13) 제공.
        rebindSlidePanelHotKey()

        slidePanelController.installSystemObservers(rebindHotKey: { [weak self] in
            self?.rebindSlidePanelHotKey()
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak slidePanelController] in
            slidePanelController?.warmUp()
        }

        return true
    }
}

extension Notification.Name {
    static let moduleRefreshRequested = Notification.Name("EdgeLauncher.moduleRefreshRequested")
}
