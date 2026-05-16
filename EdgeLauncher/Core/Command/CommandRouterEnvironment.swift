import SwiftUI

private struct CommandRouterKey: EnvironmentKey {
    @MainActor static var defaultValue: CommandRouter { CommandRouter.shared }
}

extension EnvironmentValues {
    var commandRouter: CommandRouter {
        get { self[CommandRouterKey.self] }
        set { self[CommandRouterKey.self] = newValue }
    }
}

extension CommandRouter {
    @MainActor static let shared = CommandRouter()
}

extension View {
    func commandHandler(_ handler: ModuleCommandHandler, for moduleId: String, router: CommandRouter) -> some View {
        modifier(CommandHandlerModifier(handler: handler, moduleId: moduleId, router: router))
    }
}

private struct CommandHandlerModifier: ViewModifier {
    let handler: ModuleCommandHandler
    let moduleId: String
    let router: CommandRouter

    func body(content: Content) -> some View {
        content
            .onAppear { router.register(handler, for: moduleId) }
            .onDisappear { router.unregister(moduleId: moduleId) }
    }
}
