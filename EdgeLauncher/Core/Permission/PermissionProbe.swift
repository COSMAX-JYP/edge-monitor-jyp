import Foundation
import AppKit

@MainActor
protocol PermissionProbe: AnyObject {
    var kind: PermissionKind { get }
    func currentState() async -> PermissionState
    func request() async throws -> PermissionState
}

extension PermissionProbe {
    func openSystemSettings() {
        guard let url = kind.systemSettingsURL else { return }
        NSWorkspace.shared.open(url)
    }
}
