import Combine
import SwiftUI

struct AnyEdgeModule: Identifiable {
    let id: String
    let supportsFullscreen: Bool
    let preservesInactiveRendering: Bool
    let viewBuilder: () -> AnyView
    private let titleProvider: () -> String
    private let iconProvider: () -> String
    private let becameActive: () -> Void
    private let resigned: () -> Void
    private let terminate: () async -> Void
    private let commandHandlerProvider: () -> ModuleCommandHandler?
    let requiredPermissions: [PermissionKind]

    var title: String { titleProvider() }
    var iconName: String { iconProvider() }
    var iconCustomization: IconCustomization? { iconCustomizationProvider() }

    private let iconCustomizationProvider: () -> IconCustomization?

    init<M: EdgeModule>(_ module: M) {
        self.id = module.id
        self.titleProvider = { module.title }
        self.iconProvider = { module.iconName }
        self.iconCustomizationProvider = { module.iconCustomization }
        self.supportsFullscreen = module.supportsFullscreen
        self.preservesInactiveRendering = module.preservesInactiveRendering
        self.viewBuilder = { AnyView(module.view) }
        self.becameActive = { module.didBecomeActive() }
        self.resigned = { module.didResignActive() }
        self.terminate = { await module.willTerminate() }
        self.commandHandlerProvider = { module.commandHandler }
        self.requiredPermissions = module.requiredPermissions
    }

    func didBecomeActive() { becameActive() }
    func didResignActive() { resigned() }
    func willTerminate() async { await terminate() }
    var commandHandler: ModuleCommandHandler? { commandHandlerProvider() }
}

/// 사이드바 한 칸을 나타내는 슬롯. 모듈을 담거나 비어있을 수 있다.
enum SidebarSlot: Identifiable, Equatable {
    case module(String)
    case empty(String)  // UUID string

    var id: String {
        switch self {
        case .module(let id): return "m:\(id)"
        case .empty(let uuid): return "e:\(uuid)"
        }
    }

    var moduleID: String? {
        if case .module(let id) = self { return id }
        return nil
    }

    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    var persistedToken: String {
        switch self {
        case .module(let id): return id
        case .empty(let uuid): return "__empty:\(uuid)__"
        }
    }

    static func fromToken(_ token: String) -> SidebarSlot {
        if token.hasPrefix("__empty:"), token.hasSuffix("__") {
            let start = token.index(token.startIndex, offsetBy: "__empty:".count)
            let end = token.index(token.endIndex, offsetBy: -2)
            return .empty(String(token[start..<end]))
        }
        return .module(token)
    }
}

final class ModuleRegistry: ObservableObject {
    @Published private(set) var modules: [AnyEdgeModule] = []
    @Published private(set) var hiddenIDs: Set<String> = []
    @Published private(set) var slots: [SidebarSlot] = []

    private let slotsKey = "app.sidebarSlots"
    private let orderKey = "app.moduleOrder"  // legacy
    private let hiddenKey = "app.moduleHidden"
    private let defaults: UserDefaults

    private var iconChangeObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ModuleIconCustomizationStore.migrateLegacyDiscordIcons(defaults: defaults)
        if let stored = defaults.array(forKey: hiddenKey) as? [String] {
            hiddenIDs = Set(stored)
        }
        iconChangeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("edge.module.iconChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    deinit {
        if let iconChangeObserver {
            NotificationCenter.default.removeObserver(iconChangeObserver)
        }
    }

    func register(_ module: AnyEdgeModule) {
        if let idx = modules.firstIndex(where: { $0.id == module.id }) {
            modules[idx] = module
        } else {
            modules.append(module)
        }
        rebuildSlots()
    }

    func module(id: String) -> AnyEdgeModule? {
        modules.first { $0.id == id }
    }

    func iconCustomization(for id: String) -> IconCustomization? {
        ModuleIconCustomizationStore.customization(for: id, defaults: defaults)
            ?? module(id: id)?.iconCustomization
    }

    var visibleModules: [AnyEdgeModule] {
        modules.filter { !hiddenIDs.contains($0.id) }
    }

    /// 빈 슬롯 포함, 숨김 모듈 제외한 사이드바 표시용 슬롯 목록.
    var visibleSlots: [SidebarSlot] {
        slots.filter {
            if let id = $0.moduleID { return !hiddenIDs.contains(id) && modules.contains(where: { $0.id == id }) }
            return true
        }
    }

    /// 슬롯 위치 스왑 — 빈 슬롯과도 스왑 가능 → 모듈을 고정 위치로 이동.
    func swapSlots(slotIDA: String, slotIDB: String) {
        guard slotIDA != slotIDB,
              let i = slots.firstIndex(where: { $0.id == slotIDA }),
              let j = slots.firstIndex(where: { $0.id == slotIDB }) else { return }
        slots.swapAt(i, j)
        persistSlots()
    }

    /// 끝에 빈 슬롯 추가.
    func appendEmptySlot() {
        slots.append(.empty(UUID().uuidString))
        persistSlots()
    }

    /// 빈 슬롯 제거.
    func removeSlot(slotID: String) {
        slots.removeAll { $0.id == slotID && $0.isEmpty }
        persistSlots()
    }

    /// 레거시 reorder (드래그용) — 슬롯 인덱스 기준.
    func reorder(from: Int, to: Int) {
        // 모듈 리스트 기준 인덱스를 받아 슬롯에서 해당 모듈 위치를 스왑.
        guard from != to, from >= 0, from < modules.count, to >= 0, to < modules.count else { return }
        let fromID = modules[from].id
        let toID = modules[to].id
        guard let i = slots.firstIndex(where: { $0.moduleID == fromID }),
              let j = slots.firstIndex(where: { $0.moduleID == toID }) else { return }
        // 드래그 reorder 는 "사이에 끼워넣기" 의미이므로 항목 이동.
        let entry = slots.remove(at: i)
        let insertIndex = j > i ? j : j
        slots.insert(entry, at: min(insertIndex, slots.count))
        persistSlots()

        // 레거시: modules 배열 순서도 동기화.
        let item = modules.remove(at: from)
        let insertAt = min(to, modules.count)
        modules.insert(item, at: insertAt)
        defaults.set(modules.map(\.id), forKey: orderKey)
    }

    func setVisible(_ id: String, visible: Bool) {
        if visible {
            hiddenIDs.remove(id)
        } else {
            hiddenIDs.insert(id)
        }
        defaults.set(Array(hiddenIDs), forKey: hiddenKey)
    }

    private func persistSlots() {
        defaults.set(slots.map(\.persistedToken), forKey: slotsKey)
    }

    /// 저장된 슬롯 레이아웃을 적용. 신규 모듈은 끝에 자동 추가.
    private func rebuildSlots() {
        let stored = defaults.array(forKey: slotsKey) as? [String] ?? []
        let legacyOrder = defaults.array(forKey: orderKey) as? [String] ?? []
        let registeredIDs = Set(modules.map(\.id))

        var newSlots: [SidebarSlot] = []
        var seenModuleIDs: Set<String> = []

        // 1) 기존 저장된 슬롯 레이아웃 적용 (빈 슬롯 보존).
        for token in stored {
            let slot = SidebarSlot.fromToken(token)
            switch slot {
            case .module(let id):
                if registeredIDs.contains(id), !seenModuleIDs.contains(id) {
                    newSlots.append(.module(id))
                    seenModuleIDs.insert(id)
                }
            case .empty:
                newSlots.append(slot)
            }
        }

        // 2) 저장된 슬롯이 비어있는 경우 레거시 order 적용.
        if newSlots.isEmpty, !legacyOrder.isEmpty {
            for id in legacyOrder where registeredIDs.contains(id) && !seenModuleIDs.contains(id) {
                newSlots.append(.module(id))
                seenModuleIDs.insert(id)
            }
        }

        // 3) 등록됐으나 슬롯에 없는 모듈은 끝에 추가.
        for module in modules where !seenModuleIDs.contains(module.id) {
            newSlots.append(.module(module.id))
            seenModuleIDs.insert(module.id)
        }

        slots = newSlots
    }
}
