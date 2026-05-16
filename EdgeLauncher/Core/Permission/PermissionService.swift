import Foundation
import Observation

@Observable
@MainActor
final class PermissionService {
    private(set) var states: [PermissionKind: PermissionState] = [:]

    @ObservationIgnored
    private var probes: [PermissionKind: any PermissionProbe] = [:]

    init(probes: [any PermissionProbe] = []) {
        for probe in probes {
            self.probes[probe.kind] = probe
            self.states[probe.kind] = .unknown
        }
    }

    func register(_ probe: any PermissionProbe) {
        probes[probe.kind] = probe
        if states[probe.kind] == nil {
            states[probe.kind] = .unknown
        }
    }

    func state(for kind: PermissionKind) -> PermissionState {
        states[kind] ?? .unknown
    }

    func refresh() async {
        for kind in probes.keys {
            await refresh(kind)
        }
    }

    func refresh(_ kind: PermissionKind) async {
        guard let probe = probes[kind] else { return }
        let next = await probe.currentState()
        states[kind] = next
    }

    @discardableResult
    func request(_ kind: PermissionKind) async throws -> PermissionState {
        guard let probe = probes[kind] else {
            states[kind] = .unknown
            return .unknown
        }
        let next = try await probe.request()
        states[kind] = next
        return next
    }

    func openSettings(for kind: PermissionKind) {
        probes[kind]?.openSystemSettings()
    }
}
