import Foundation

@MainActor
final class KanbanSlidePanelHotKey {
    private let registrar: HotKeyRegistrar
    private var token: HotKeyToken?
    private(set) var currentKeyCode: Int?
    private(set) var currentModifiers: UInt32?
    private(set) var lastError: HotKeyRegistrarError?

    init(registrar: HotKeyRegistrar = CarbonHotKeyRegistrar.shared) {
        self.registrar = registrar
    }

    deinit {
        // v2.1: deinit 에서 hotkey 누락 방지. MainActor 격리 외에서 호출 가능하므로 nonisolated dispatch.
        if let t = token { Task { @MainActor [registrar] in registrar.unregister(t) } }
    }

    /// 새 단축키로 bind. 같은 combo 면 OS 가 두 번째 register 를 실패시킬 수 있으므로,
    /// 동일 combo 는 먼저 unregister 후 다시 register (refresh 의미).
    /// 다른 combo 는 register-first / unregister-second (실패 시 기존 보존).
    func bind(keyCode: Int, modifiers: UInt32, action: @escaping () -> Void) throws {
        if currentKeyCode == keyCode && currentModifiers == modifiers {
            // 같은 조합 — 기존 해제 후 다시 등록 (wake refresh 류).
            if let old = token { registrar.unregister(old); token = nil }
            do {
                let new = try registrar.register(keyCode: keyCode, modifiers: modifiers, handler: action)
                token = new
                currentKeyCode = keyCode
                currentModifiers = modifiers
                lastError = nil
            } catch let e as HotKeyRegistrarError {
                // 재등록 실패 — unbound + error 로 정확히 표시.
                currentKeyCode = nil
                currentModifiers = nil
                lastError = e
                throw e
            }
            return
        }

        // 다른 조합 — register-first.
        do {
            let newToken = try registrar.register(keyCode: keyCode, modifiers: modifiers, handler: action)
            if let old = token { registrar.unregister(old) }
            token = newToken
            currentKeyCode = keyCode
            currentModifiers = modifiers
            lastError = nil
        } catch let e as HotKeyRegistrarError {
            lastError = e
            throw e
        }
    }

    /// 같은 combo 를 다시 새로 등록. wake/Mission Control/스페이스 전환 후 강제 refresh 용.
    /// 내부적으로 bind 가 동일 combo 분기를 타게 한다.
    func rebindExisting(action: @escaping () -> Void) throws {
        guard let k = currentKeyCode, let m = currentModifiers else { return }
        try bind(keyCode: k, modifiers: m, action: action)
    }

    func unbind() {
        if let t = token { registrar.unregister(t) }
        token = nil
        currentKeyCode = nil
        currentModifiers = nil
    }
}
