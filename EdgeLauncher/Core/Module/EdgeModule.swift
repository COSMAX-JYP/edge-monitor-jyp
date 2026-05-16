import SwiftUI

protocol EdgeModule {
    associatedtype Body: View
    var id: String { get }
    var title: String { get }
    var iconName: String { get }
    var supportsFullscreen: Bool { get }
    var preservesInactiveRendering: Bool { get }
    @ViewBuilder var view: Body { get }

    var commandHandler: ModuleCommandHandler? { get }
    var requiredPermissions: [PermissionKind] { get }
    var iconCustomization: IconCustomization? { get }

    func didBecomeActive()
    func didResignActive()
    func willTerminate() async
}

extension EdgeModule {
    var preservesInactiveRendering: Bool { false }
    var commandHandler: ModuleCommandHandler? { nil }
    var requiredPermissions: [PermissionKind] { [] }
    var iconCustomization: IconCustomization? { nil }
    func didBecomeActive() {}
    func didResignActive() {}
    func willTerminate() async {}
}

protocol EdgeModuleIconCustomizable {
    var iconCustomization: IconCustomization? { get }
}

extension EdgeModule {
    var iconCustomizationProvider: IconCustomization? { iconCustomization }
}
