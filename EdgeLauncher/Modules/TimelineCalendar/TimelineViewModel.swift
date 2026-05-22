import Foundation
import Observation
import EventKit

@Observable
@MainActor
final class TimelineViewModel {
    var currentDay: Date
    var viewMode: TimelineViewMode = .day
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

    var outlookSignedIn: Bool = false
    var outlookUsername: String?

    @ObservationIgnored
    private let provider: any CalendarProvider
    @ObservationIgnored
    private let permission: PermissionService
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?
    @ObservationIgnored
    private let eventStore: EKEventStore?
    @ObservationIgnored
    private var storeChangeObserver: NSObjectProtocol?
    @ObservationIgnored
    let msalAuth: MSALAuthService?
    let visibilityStore: CalendarVisibilityStore
    @ObservationIgnored
    let attendeeSearchService: AttendeeSearchService?

    var sidebarVisible: Bool = true

    init(
        provider: any CalendarProvider,
        permission: PermissionService,
        eventStore: EKEventStore? = nil,
        msalAuth: MSALAuthService? = nil,
        visibilityStore: CalendarVisibilityStore? = nil,
        initialDay: Date = Date()
    ) {
        self.provider = provider
        self.permission = permission
        self.eventStore = eventStore
        self.msalAuth = msalAuth
        self.visibilityStore = visibilityStore ?? CalendarVisibilityStore()
        self.attendeeSearchService = msalAuth.map { AttendeeSearchService(auth: $0) }
        let cal = Calendar.current
        self.currentDay = cal.startOfDay(for: initialDay)
        refreshOutlookState()
        if let store = eventStore {
            let center = NotificationCenter.default
            storeChangeObserver = center.addObserver(
                forName: .EKEventStoreChanged,
                object: store,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.reload()
                }
            }
        }
    }

    deinit {
        refreshTask?.cancel()
        if let storeChangeObserver {
            NotificationCenter.default.removeObserver(storeChangeObserver)
        }
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

    func refreshOutlookState() {
        guard let auth = msalAuth else {
            outlookSignedIn = false
            outlookUsername = nil
            return
        }
        if let account = auth.currentAccount() {
            outlookSignedIn = true
            outlookUsername = account.username
        } else {
            outlookSignedIn = false
            outlookUsername = nil
        }
    }

    func signInOutlook() async {
        guard let auth = msalAuth else { return }
        errorMessage = nil
        do {
            let result = try await auth.signIn()
            outlookSignedIn = true
            outlookUsername = result.username
            await loadCalendars()
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOutOutlook() async {
        guard let auth = msalAuth else { return }
        do {
            try await auth.signOut()
            outlookSignedIn = false
            outlookUsername = nil
            await loadCalendars()
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCalendars() async {
        do {
            let list = try await provider.availableCalendars()
            calendars = list.sorted { $0.title < $1.title }
            visibilityStore.initializeIfNeeded(with: list.map { $0.id })
            defaultCalendarId = try await provider.defaultCalendarId()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleCalendarVisibility(_ calendarId: String) {
        visibilityStore.toggle(calendarId)
        Task { await reload() }
    }

    func toggleSidebar() {
        sidebarVisible.toggle()
    }

    func reload() async {
        guard permissionState.isUsable else { return }
        refreshTask?.cancel()
        let cal = Calendar.current
        let days: [Date] = visibleDays(from: currentDay, mode: viewMode, calendar: cal)
        let anchor = currentDay
        isLoading = true
        errorMessage = nil
        do {
            var collected: [TimelineEvent] = []
            for day in days {
                let chunk = try await provider.fetchEvents(on: day)
                collected.append(contentsOf: chunk)
            }
            if cal.isDate(anchor, inSameDayAs: currentDay), viewMode == viewMode {
                let unique = Self.dedupe(collected)
                events = unique
                    .filter { visibilityStore.isVisible(calendarId(of: $0)) }
                    .sorted { $0.start < $1.start }
            }
        } catch CalendarProviderError.notAuthorized {
            permissionState = .denied
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func setViewMode(_ mode: TimelineViewMode) {
        guard viewMode != mode else { return }
        viewMode = mode
        Task { await reload() }
    }

    func visibleDays(from anchor: Date, mode: TimelineViewMode, calendar: Calendar = .current) -> [Date] {
        let day = calendar.startOfDay(for: anchor)
        switch mode {
        case .day:
            return [day]
        case .week:
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: day)?.start else { return [day] }
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        case .month:
            guard let monthRange = calendar.range(of: .day, in: .month, for: day),
                  let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: day)) else {
                return [day]
            }
            return monthRange.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) }
        }
    }

    private func calendarId(of event: TimelineEvent) -> String {
        switch event.source {
        case .apple(let id): return id
        case .outlook(let id, _): return id
        case .local(let id): return id
        }
    }

    private static func dedupe(_ events: [TimelineEvent]) -> [TimelineEvent] {
        var seen = Set<String>()
        var result: [TimelineEvent] = []
        for event in events {
            if seen.insert(event.id).inserted {
                result.append(event)
            }
        }
        return result
    }

    func goToToday() {
        let today = Calendar.current.startOfDay(for: Date())
        guard !Calendar.current.isDate(today, inSameDayAs: currentDay) else { return }
        currentDay = today
        Task { await reload() }
    }

    func goToPrevious() {
        let cal = Calendar.current
        let next: Date?
        switch viewMode {
        case .day:
            next = cal.date(byAdding: .day, value: -1, to: currentDay)
        case .week:
            next = cal.date(byAdding: .weekOfYear, value: -1, to: currentDay)
        case .month:
            next = cal.date(byAdding: .month, value: -1, to: currentDay)
        }
        guard let target = next else { return }
        currentDay = target
        Task { await reload() }
    }

    func goToNext() {
        let cal = Calendar.current
        let next: Date?
        switch viewMode {
        case .day:
            next = cal.date(byAdding: .day, value: 1, to: currentDay)
        case .week:
            next = cal.date(byAdding: .weekOfYear, value: 1, to: currentDay)
        case .month:
            next = cal.date(byAdding: .month, value: 1, to: currentDay)
        }
        guard let target = next else { return }
        currentDay = target
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
        let preferredId = preferredDefaultCalendarId()
        editorDraft = EventDraft(
            title: "",
            notes: "",
            location: "",
            start: begin,
            end: end,
            isAllDay: false,
            calendarId: preferredId
        )
        editorTargetEvent = nil
    }

    private func preferredDefaultCalendarId() -> String {
        // 참석자 초대 가능한 Outlook 캘린더(본인 소유, 수정 가능)를 최우선.
        if outlookSignedIn {
            let outlookEditable = calendars.first { $0.providerKind == .outlook && $0.allowsModifications }
            if let id = outlookEditable?.id { return id }
        }
        if let def = defaultCalendarId, calendars.contains(where: { $0.id == def && $0.allowsModifications }) {
            return def
        }
        return calendars.first(where: { $0.allowsModifications })?.id ?? ""
    }

    func startEditEvent(_ event: TimelineEvent) {
        var draft = EventDraft(
            title: event.title,
            notes: event.notes ?? "",
            location: event.location ?? "",
            start: event.start,
            end: event.end,
            isAllDay: event.isAllDay,
            calendarId: "",
            attendees: event.attendees
        )
        switch event.source {
        case .apple(let calId): draft.calendarId = calId
        case .outlook(let calId, _): draft.calendarId = calId
        case .local(let calId): draft.calendarId = calId
        }
        editorDraft = draft
        editorTargetEvent = event
        detailEvent = nil
    }

    func respondToOutlookEvent(_ event: TimelineEvent, action: GraphCalendarProvider.ResponseAction, comment: String?) async {
        errorMessage = nil
        guard case .outlook = event.source else { return }
        guard let provider = outlookProvider() else { return }
        do {
            try await provider.respondToEvent(event, response: action, comment: comment, sendResponse: true)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func outlookProvider() -> GraphCalendarProvider? {
        if let agg = provider as? AggregatingCalendarProvider {
            return agg.findProvider(of: .outlook) as? GraphCalendarProvider
        }
        return provider as? GraphCalendarProvider
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
