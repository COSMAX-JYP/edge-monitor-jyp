import XCTest
@testable import EdgeLauncher

@MainActor
final class PermissionServiceTests: XCTestCase {

    private final class StubProbe: PermissionProbe {
        let kind: PermissionKind
        var nextCurrent: PermissionState
        var nextRequest: PermissionState
        var requestThrows: Error?
        var currentCallCount = 0
        var requestCallCount = 0

        init(kind: PermissionKind, current: PermissionState = .notDetermined, request: PermissionState = .authorized) {
            self.kind = kind
            self.nextCurrent = current
            self.nextRequest = request
        }

        func currentState() async -> PermissionState {
            currentCallCount += 1
            return nextCurrent
        }

        func request() async throws -> PermissionState {
            requestCallCount += 1
            if let requestThrows { throw requestThrows }
            return nextRequest
        }
    }

    func test_refresh_writesStatesFromProbes() async {
        let calendar = StubProbe(kind: .calendar, current: .authorized)
        let accessibility = StubProbe(kind: .accessibility, current: .denied)
        let service = PermissionService(probes: [calendar, accessibility])

        await service.refresh()

        XCTAssertEqual(service.state(for: .calendar), .authorized)
        XCTAssertEqual(service.state(for: .accessibility), .denied)
    }

    func test_refresh_singleKind_doesNotTouchOthers() async {
        let calendar = StubProbe(kind: .calendar, current: .authorized)
        let accessibility = StubProbe(kind: .accessibility, current: .denied)
        let service = PermissionService(probes: [calendar, accessibility])

        await service.refresh(.calendar)

        XCTAssertEqual(service.state(for: .calendar), .authorized)
        XCTAssertEqual(service.state(for: .accessibility), .unknown)
        XCTAssertEqual(accessibility.currentCallCount, 0)
    }

    func test_request_writesResultAndReturns() async throws {
        let probe = StubProbe(kind: .calendar, request: .authorized)
        let service = PermissionService(probes: [probe])

        let result = try await service.request(.calendar)

        XCTAssertEqual(result, .authorized)
        XCTAssertEqual(service.state(for: .calendar), .authorized)
        XCTAssertEqual(probe.requestCallCount, 1)
    }

    func test_request_unknownKind_returnsUnknown() async throws {
        let service = PermissionService(probes: [])
        let result = try await service.request(.calendar)
        XCTAssertEqual(result, .unknown)
    }

    func test_register_addsProbeAtRuntime() async {
        let service = PermissionService()
        let probe = StubProbe(kind: .accessibility, current: .authorized)
        service.register(probe)
        await service.refresh(.accessibility)
        XCTAssertEqual(service.state(for: .accessibility), .authorized)
    }

    func test_permissionState_helpers() {
        XCTAssertTrue(PermissionState.authorized.isUsable)
        XCTAssertTrue(PermissionState.writeOnly.isUsable)
        XCTAssertFalse(PermissionState.denied.isUsable)
        XCTAssertTrue(PermissionState.denied.needsUserAction)
        XCTAssertFalse(PermissionState.authorized.needsUserAction)
    }
}
