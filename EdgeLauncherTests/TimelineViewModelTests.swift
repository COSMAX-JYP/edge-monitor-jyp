import XCTest
@testable import EdgeLauncher

@MainActor
final class TimelineViewModelTests: XCTestCase {

    final class StubProvider: CalendarProvider {
        let source: CalendarSourceKind = .apple
        var events: [TimelineEvent] = []
        var calendars: [CalendarChoice] = []
        var defaultId: String? = nil
        var shouldThrow: Error?
        var fetchCount = 0
        var saveCount = 0
        var updateCount = 0
        var deleteCount = 0
        var capturedDay: Date?

        func fetchEvents(on day: Date) async throws -> [TimelineEvent] {
            fetchCount += 1
            capturedDay = day
            if let shouldThrow { throw shouldThrow }
            return events
        }

        func availableCalendars() async throws -> [CalendarChoice] {
            calendars
        }

        func defaultCalendarId() async throws -> String? {
            defaultId
        }

        func saveEvent(_ draft: EventDraft) async throws -> TimelineEvent {
            saveCount += 1
            let event = TimelineEvent(
                source: .apple(calendarId: draft.calendarId),
                calendarItemIdentifier: UUID().uuidString,
                occurrenceStart: draft.start,
                title: draft.title,
                start: draft.start,
                end: draft.end,
                isAllDay: draft.isAllDay
            )
            events.append(event)
            return event
        }

        func updateEvent(_ event: TimelineEvent, draft: EventDraft) async throws -> TimelineEvent {
            updateCount += 1
            var updated = event
            updated.title = draft.title
            updated.start = draft.start
            updated.end = draft.end
            if let idx = events.firstIndex(where: { $0.id == event.id }) {
                events[idx] = updated
            }
            return updated
        }

        func deleteEvent(_ event: TimelineEvent) async throws {
            deleteCount += 1
            events.removeAll { $0.id == event.id }
        }
    }

    final class StubProbe: PermissionProbe {
        let kind: PermissionKind = .calendar
        var current: PermissionState = .notDetermined
        var requestResult: PermissionState = .authorized

        func currentState() async -> PermissionState { current }
        func request() async throws -> PermissionState {
            current = requestResult
            return requestResult
        }
    }

    private func makeEvent(title: String) -> TimelineEvent {
        TimelineEvent(
            source: .apple(calendarId: "cal"),
            calendarItemIdentifier: title,
            occurrenceStart: Date(),
            title: title,
            start: Date(),
            end: Date().addingTimeInterval(3600)
        )
    }

    func test_onAppear_requestsPermissionIfNotDetermined_thenLoads() async {
        let probe = StubProbe()
        probe.current = .notDetermined
        probe.requestResult = .authorized
        let service = PermissionService(probes: [probe])
        let provider = StubProvider()
        provider.events = [makeEvent(title: "Meet")]
        let vm = TimelineViewModel(provider: provider, permission: service)

        await vm.onAppear()

        XCTAssertEqual(vm.permissionState, .authorized)
        XCTAssertEqual(vm.events.count, 1)
        XCTAssertEqual(provider.fetchCount, 1)
    }

    func test_onAppear_skipsLoadWhenDenied() async {
        let probe = StubProbe()
        probe.current = .denied
        let service = PermissionService(probes: [probe])
        let provider = StubProvider()
        let vm = TimelineViewModel(provider: provider, permission: service)

        await vm.onAppear()

        XCTAssertEqual(vm.permissionState, .denied)
        XCTAssertEqual(provider.fetchCount, 0)
    }

    func test_goToNext_changesDay_andReloads() async {
        let probe = StubProbe()
        probe.current = .authorized
        let service = PermissionService(probes: [probe])
        let provider = StubProvider()
        let vm = TimelineViewModel(provider: provider, permission: service, initialDay: Date())
        await vm.onAppear()
        let day1 = vm.currentDay

        vm.goToNext()
        await Task.yield()
        await Task.yield()

        XCTAssertGreaterThan(vm.currentDay.timeIntervalSince(day1), 0)
    }

    func test_goToPrevious_changesDay() async {
        let probe = StubProbe()
        probe.current = .authorized
        let service = PermissionService(probes: [probe])
        let provider = StubProvider()
        let vm = TimelineViewModel(provider: provider, permission: service)
        await vm.onAppear()
        let day1 = vm.currentDay

        vm.goToPrevious()

        XCTAssertLessThan(vm.currentDay.timeIntervalSince(day1), 0)
    }

    func test_goToToday_resetsToToday() async {
        let probe = StubProbe()
        probe.current = .authorized
        let service = PermissionService(probes: [probe])
        let provider = StubProvider()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let vm = TimelineViewModel(provider: provider, permission: service, initialDay: yesterday)
        await vm.onAppear()

        vm.goToToday()

        XCTAssertTrue(Calendar.current.isDateInToday(vm.currentDay))
    }

    func test_reload_setsErrorOnFailure() async {
        let probe = StubProbe()
        probe.current = .authorized
        let service = PermissionService(probes: [probe])
        let provider = StubProvider()
        provider.shouldThrow = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        let vm = TimelineViewModel(provider: provider, permission: service)

        await vm.refreshPermission()
        await vm.reload()

        XCTAssertEqual(vm.errorMessage, "boom")
    }

    func test_reload_notAuthorizedError_setsStateDenied() async {
        let probe = StubProbe()
        probe.current = .authorized
        let service = PermissionService(probes: [probe])
        let provider = StubProvider()
        provider.shouldThrow = CalendarProviderError.notAuthorized
        let vm = TimelineViewModel(provider: provider, permission: service)

        await vm.refreshPermission()
        await vm.reload()

        XCTAssertEqual(vm.permissionState, .denied)
    }
}
