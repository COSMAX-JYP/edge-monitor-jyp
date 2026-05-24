import Foundation

struct HotKeyToken: Hashable {
    let id: UInt32
}

enum HotKeyRegistrarError: Error, Equatable {
    case registrationFailed(status: Int32)
    case handlerInstallFailed(status: Int32)
}

@MainActor
protocol HotKeyRegistrar: AnyObject {
    @discardableResult
    func register(keyCode: Int, modifiers: UInt32, handler: @escaping () -> Void) throws -> HotKeyToken
    func unregister(_ token: HotKeyToken)
}
