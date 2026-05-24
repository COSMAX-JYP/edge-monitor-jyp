import AppKit
import Carbon.HIToolbox

@MainActor
final class CarbonHotKeyRegistrar: HotKeyRegistrar {
    static let shared = CarbonHotKeyRegistrar()

    static let appSignature: OSType = OSType(0x534C4B42) // 'SLKB'

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextId: UInt32 = 1
    private var eventHandlerInstalled = false
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    @discardableResult
    func register(keyCode: Int, modifiers: UInt32, handler: @escaping () -> Void) throws -> HotKeyToken {
        try installEventHandlerIfNeeded()

        let id = nextId
        nextId += 1
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: Self.appSignature, id: id)
        let status = RegisterEventHotKey(UInt32(keyCode), modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            throw HotKeyRegistrarError.registrationFailed(status: status)
        }
        handlers[id] = handler
        refs[id] = ref
        return HotKeyToken(id: id)
    }

    func unregister(_ token: HotKeyToken) {
        if let ref = refs[token.id] {
            UnregisterEventHotKey(ref)
            refs[token.id] = nil
        }
        handlers[token.id] = nil
    }

    /// 콜백에서 들어온 EventHotKeyID 가 우리 것인지 + 등록된 id 인지 확인.
    static func shouldDispatch(_ hkID: EventHotKeyID, knownIds: Set<UInt32>) -> Bool {
        guard hkID.signature == appSignature else { return false }
        return knownIds.contains(hkID.id)
    }

    fileprivate func dispatch(_ hkID: EventHotKeyID) {
        guard hkID.signature == Self.appSignature else { return }
        handlers[hkID.id]?()
    }

    private func installEventHandlerIfNeeded() throws {
        guard !eventHandlerInstalled else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData, let event else { return noErr }
            let me = Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            let r = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            guard r == noErr else { return r }
            Task { @MainActor in me.dispatch(hkID) }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandlerRef)
        guard status == noErr else { throw HotKeyRegistrarError.handlerInstallFailed(status: status) }
        eventHandlerInstalled = true
    }
}
