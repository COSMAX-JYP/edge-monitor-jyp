import Foundation
import ApplicationServices

@MainActor
final class AccessibilityPermissionProbe: PermissionProbe {
    let kind: PermissionKind = .accessibility

    init() {}

    func currentState() async -> PermissionState {
        let trusted = AXIsProcessTrusted()
        return trusted ? .authorized : .notDetermined
    }

    func request() async throws -> PermissionState {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        return trusted ? .authorized : .notDetermined
    }
}
