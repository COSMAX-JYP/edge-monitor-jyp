import Foundation
import Observation

@Observable
@MainActor
final class TimelineViewModel {
    var currentDay: Date
    var events: [TimelineEvent] = []
    var calendars: [CalendarChoice] = []
    var defaultCalendarId: String?
    var permissionState: PermissionState = .unknown
    var isLoading: Bool = false
    var errorMessage: String?

    var editorDraft: EventDraft?
    var editorTargetEvent: TimelineEvent?
    var detailEvent: TimelineEvent?
    var pendingDeleteEvent: TimelineEvent?

    @ObservationIgnored
    private let provider: any CalendarProvider
    @ObservationIgnored
    private let permission: PermissionService
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    init(
        provider: any CalendarProvider,
        permission: PermissionService,
        initialDay: Date = Date()
    ) {
        self.provider = provider
        self.permission = permission
        let cal = Calendar.current
        self.currentDay = cal.startOfDay(for: initialDay)
    }

    deinit {
        refreshTask?.cancel()
    }

    func onAppear() async {
        await refreshPermission()
        if permissionState == .notDetermined {
            await requestPermission()
        }
        if permissionState.isUsable {
            await loadCalendars()
            await reload()
        }
    }

    func refreshPermission() async {
        await permission.refresh(.calendar)
        permissionState = permission.state(for: .calendar)
    }

    func requestPermission() async {
        do {
            permissionState = try await permission.request(.calendar)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openSettings() {
        permission.openSettings(for: .calendar)
    }

    func loadCalendars() async {
        do {
            let list = try await provider.availableCalendars()
            calendars = list.sorted { $0.title < $1.title }
            defaultCalendarId = try await provider.defaultCalendarId()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reload() async {
        guard permissionState.isUsable else { return }
        refreshTask?.cancel()
        let day = currentDay
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await provider.fetchEvents(on: day)
            if Calendar.current.isDate(day, inSameDayAs: currentDay) {
                events = fetched.sorted { $0.start < $1.start }
            }
        } catch CalendarProviderError.notAuthorized {
            permissionState = .denied
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func goToToday() {
        let today = Calendar.current.startOfDay(for: Date())
        guard !Calendar.current.isDate(today, inSameDayAs: currentDay) else { return }
        currentDay = today
        Task { await reload() }
    }

    func goToPrevious() {
        guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: currentDay) else { return }
        currentDay = prev
        Task { await reload() }
    }

    func goToNext() {
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: currentDay) else { return }
        currentDay = next
        Task { await reload() }
    }

    func setDay(_ day: Date) {
        let normalized = Calendar.current.startOfDay(for: day)
        guard !Calendar.current.isDate(normalized, inSameDayAs: currentDay) else { return }
        currentDay = normalized
        Task { await reload() }
    }

    // MARK: - Mutations

    func startNewEvent(at start: Date? = nil, durationMinutes: Int = 60) {
        let begin = start ?? defaultStartForToday()
        let end = begin.addingTimeInterval(TimeInterval(durationMinutes * 60))
        editorDraft = EventDraft(
            title: "",
            notes: "",
            location: "",
            start: begin,
            end: end,
            isAllDay: false,
            calendarId: defaultCalendarId ?? calendars.first(where: { $0.allowsModifications })?.id ?? ""
        )
        editorTargetEvent = nil
    }

    func startEditEvent(_ event: TimelineEvent) {
        var draft = EventDraft(
            title: event.title,
            notes: event.notes ?? "",
            location: event.location ?? "",
            start: event.start,
            end: event.end,
            isAllDay: event.isAllDay,
            calendarId: ""
        )
        if case .apple(let calId) = event.source { draft.calendarId = calId }
        editorDraft = draft
        editorTargetEvent = event
        detailEvent = nil
    }

    func cancelEditing() {
        editorDraft = nil
        editorTargetEvent = nil
    }

    func saveEditor(_ draft: EventDraft) async {
        errorMessage = nil
        do {
            if let target = editorTargetEvent {
                let updated = try await provider.updateEvent(target, draft: draft)
                replaceEvent(target.id, with: updated)
            } else {
                let saved = try await provider.saveEvent(draft)
                events.append(saved)
                events.sort { $0.start < $1.start }
            }
            editorDraft = nil
            editorTargetEvent = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showDetail(_ event: TimelineEvent) {
        detailEvent = event
    }

    func dismissDetail() {
        detailEvent = nil
    }

    func requestDelete(_ event: TimelineEvent) {
        pendingDeleteEvent = event
    }

    func cancelDelete() { pendingDeleteEvent = nil }

    func confirmDelete() async {
        guard let event = pendingDeleteEvent else { return }
        errorMessage = nil
        do {
            try await provider.deleteEvent(event)
            events.removeAll { $0.id == event.id }
            if detailEvent?.id == event.id { detailEvent = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
        pendingDeleteEvent = nil
    }

    private func replaceEvent(_ id: String, with new: TimelineEvent) {
        if let idx = events.firstIndex(where: { $0.id == id }) {
            events[idx] = new
        } else {
            events.append(new)
        }
        events.sort { $0.start < $1.start }
        if detailEvent?.id == id { detailEvent = new }
    }

    private func defaultStartForToday() -> Date {
        let cal = Calendar.current
        let baseDay = cal.startOfDay(for: currentDay)
        let now = Date()
        if cal.isDate(currentDay, inSameDayAs: now) {
            let minute = cal.component(.minute, from: now)
            let rounded = (minute / 15) * 15
            return cal.date(bySettingHour: cal.component(.hour, from: now), minute: rounded, second: 0, of: now) ?? now
        } else {
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: baseDay) ?? baseDay
        }
    }
}

extension EventDraft: Identifiable {
    public var id: String { "\(start.timeIntervalSince1970)-\(title.hashValue)" }
}
