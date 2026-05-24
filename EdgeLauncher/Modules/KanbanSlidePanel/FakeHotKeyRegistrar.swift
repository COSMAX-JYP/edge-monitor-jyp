import Foundation

@MainActor
final class FakeHotKeyRegistrar: HotKeyRegistrar {
    struct Entry {
        let token: HotKeyToken
        let keyCode: Int
        let modifiers: UInt32
        let handler: () -> Void
    }

    private(set) var activeRegistrations: [Entry] = []
    var shouldFailNextRegister: HotKeyRegistrarError?
    private var nextId: UInt32 = 1

    @discardableResult
    func register(keyCode: Int, modifiers: UInt32, handler: @escaping () -> Void) throws -> HotKeyToken {
        if let err = shouldFailNextRegister {
            shouldFailNextRegister = nil
            throw err
        }
        let token = HotKeyToken(id: nextId)
        nextId += 1
        activeRegistrations.append(Entry(token: token, keyCode: keyCode, modifiers: modifiers, handler: handler))
        return token
    }

    func unregister(_ token: HotKeyToken) {
        activeRegistrations.removeAll { $0.token == token }
    }

    func trigger(token: HotKeyToken) {
        activeRegistrations.first { $0.token == token }?.handler()
    }
}
