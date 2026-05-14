import Combine
import EventKit
import Foundation

@MainActor
final class EventStoreVM: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var reminders: [EKReminder] = []
    @Published var hasEventAccess: Bool = false
    @Published var hasReminderAccess: Bool = false
    @Published var errorMessage: String?

    private let store = EKEventStore()

    func requestAccess() async {
        do {
            if #available(macOS 14, *) {
                hasEventAccess = try await store.requestFullAccessToEvents()
            } else {
                hasEventAccess = try await store.requestAccess(to: .event)
            }
        } catch {
            hasEventAccess = false
            errorMessage = error.localizedDescription
        }
        do {
            if #available(macOS 14, *) {
                hasReminderAccess = try await store.requestFullAccessToReminders()
            } else {
                hasReminderAccess = try await store.requestAccess(to: .reminder)
            }
        } catch {
            hasReminderAccess = false
        }
        if hasEventAccess { reloadEvents() }
        if hasReminderAccess { reloadReminders() }
    }

    func reloadEvents() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    func reloadReminders() {
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { [weak self] fetched in
            Task { @MainActor in
                guard let self else { return }
                let list = (fetched ?? []).sorted { a, b in
                    let da = a.dueDateComponents?.date ?? Date.distantFuture
                    let db = b.dueDateComponents?.date ?? Date.distantFuture
                    if da == db { return (a.title ?? "") < (b.title ?? "") }
                    return da < db
                }
                self.reminders = Array(list.prefix(20))
            }
        }
    }

    func toggleComplete(_ reminder: EKReminder) {
        reminder.isCompleted.toggle()
        do {
            try store.save(reminder, commit: true)
            reloadReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
