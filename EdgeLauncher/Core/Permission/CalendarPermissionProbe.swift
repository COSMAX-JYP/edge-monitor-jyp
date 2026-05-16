import Foundation
import EventKit

@MainActor
final class CalendarPermissionProbe: PermissionProbe {
    let kind: PermissionKind = .calendar
    private let store: EKEventStore

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    func currentState() async -> PermissionState {
        Self.map(EKEventStore.authorizationStatus(for: .event))
    }

    func request() async throws -> PermissionState {
        if #available(macOS 14.0, *) {
            do {
                let granted = try await store.requestFullAccessToEvents()
                return granted ? .authorized : .denied
            } catch {
                return Self.map(EKEventStore.authorizationStatus(for: .event))
            }
        } else {
            return await withCheckedContinuation { (cont: CheckedContinuation<PermissionState, Never>) in
                store.requestAccess(to: .event) { granted, _ in
                    cont.resume(returning: granted ? .authorized : .denied)
                }
            }
        }
    }

    static func map(_ status: EKAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        case .writeOnly: return .writeOnly
        case .fullAccess: return .authorized
        case .authorized: return .authorized
        @unknown default: return .unknown
        }
    }
}
