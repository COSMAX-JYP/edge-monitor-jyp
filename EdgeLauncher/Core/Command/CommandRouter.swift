import Foundation
import Observation

@Observable
@MainActor
final class CommandRouter {
    private(set) var activeModuleId: String?

    @ObservationIgnored
    private var handlers: [String: WeakBox] = [:]

    @ObservationIgnored
    private var globalDefaults: [ModuleCommand: () -> Void] = [:]

    init() {}

    func setActive(_ moduleId: String?) {
        activeModuleId = moduleId
    }

    func register(_ handler: ModuleCommandHandler, for moduleId: String) {
        handlers[moduleId] = WeakBox(handler)
    }

    func unregister(moduleId: String) {
        handlers.removeValue(forKey: moduleId)
    }

    func setGlobalDefault(_ command: ModuleCommand, action: @escaping () -> Void) {
        globalDefaults[command] = action
    }

    @discardableResult
    func dispatch(_ command: ModuleCommand) -> Bool {
        compactWeakHandlers()
        if let active = activeModuleId,
           let handler = handlers[active]?.value,
           handler.handle(command) {
            return true
        }
        if let fallback = globalDefaults[command] {
            fallback()
            return true
        }
        return false
    }

    private func compactWeakHandlers() {
        handlers = handlers.filter { $0.value.value != nil }
    }

    @MainActor
    private final class WeakBox {
        weak var value: ModuleCommandHandler?
        init(_ value: ModuleCommandHandler) { self.value = value }
    }
}
