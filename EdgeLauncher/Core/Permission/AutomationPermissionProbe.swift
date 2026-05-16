import Foundation
import AppKit

@MainActor
final class AutomationPermissionProbe: PermissionProbe {
    let kind: PermissionKind = .automation
    private let targetBundleIdentifier: String

    init(targetBundleIdentifier: String = "com.apple.systemevents") {
        self.targetBundleIdentifier = targetBundleIdentifier
    }

    func currentState() async -> PermissionState {
        Self.probe(bundleIdentifier: targetBundleIdentifier, askIfNeeded: false)
    }

    func request() async throws -> PermissionState {
        Self.probe(bundleIdentifier: targetBundleIdentifier, askIfNeeded: true)
    }

    private static func probe(bundleIdentifier: String, askIfNeeded: Bool) -> PermissionState {
        guard let bundleData = bundleIdentifier.data(using: .utf8) else {
            return .unknown
        }
        let target = bundleData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> NSAppleEventDescriptor in
            NSAppleEventDescriptor(
                descriptorType: typeApplicationBundleID,
                bytes: raw.baseAddress,
                length: raw.count
            ) ?? NSAppleEventDescriptor.null()
        }
        guard let aeDescPtr = target.aeDesc else {
            return .unknown
        }
        let status = AEDeterminePermissionToAutomateTarget(aeDescPtr, typeWildCard, typeWildCard, askIfNeeded)
        return map(status: status)
    }

    private static func map(status: OSStatus) -> PermissionState {
        switch Int(status) {
        case 0: return .authorized
        case Int(errAEEventNotPermitted): return .denied
        case Int(errAEEventWouldRequireUserConsent): return .notDetermined
        case Int(procNotFound): return .restricted
        default: return .unknown
        }
    }
}
