import Combine
import EventKit
import Foundation

@MainActor
final class EventStoreVM: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var hasAccess: Bool = false
    @Published var errorMessage: String?

    private let store = EKEventStore()

    func requestAccess() async {
        do {
            let granted: Bool
            if #available(macOS 14, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            hasAccess = granted
            if granted { reload() }
        } catch {
            hasAccess = false
            errorMessage = error.localizedDescription
        }
    }

    func reload() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }
}
