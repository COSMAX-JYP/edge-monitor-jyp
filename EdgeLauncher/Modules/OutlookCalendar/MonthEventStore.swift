import Combine
import EventKit
import Foundation
import os

@MainActor
final class MonthEventStore: ObservableObject {
    @Published var eventsByDay: [Date: [EKEvent]] = [:]
    @Published var hasAccess: Bool = false

    private let store = EKEventStore()

    func requestAccess() async {
        do {
            if #available(macOS 14, *) {
                hasAccess = try await store.requestFullAccessToEvents()
            } else {
                hasAccess = try await store.requestAccess(to: .event)
            }
        } catch {
            hasAccess = false
            AppLog.event.error("Month calendar access: \(error.localizedDescription)")
        }
    }

    func reload(for month: Date) {
        let cal = Calendar.current
        guard let monthInterval = cal.dateInterval(of: .month, for: month) else { return }
        // 캘린더 그리드는 보통 이전 월 며칠 + 해당 월 + 다음 월 며칠을 포함한다. 6주(42일) 범위.
        let firstWeekday = cal.component(.weekday, from: monthInterval.start)
        let gridStart = cal.date(byAdding: .day, value: -(firstWeekday - 1), to: monthInterval.start) ?? monthInterval.start
        guard let gridEnd = cal.date(byAdding: .day, value: 42, to: gridStart) else { return }

        let predicate = store.predicateForEvents(withStart: gridStart, end: gridEnd, calendars: nil)
        let raw = store.events(matching: predicate)

        var grouped: [Date: [EKEvent]] = [:]
        for event in raw {
            let day = cal.startOfDay(for: event.startDate)
            grouped[day, default: []].append(event)
        }
        for key in grouped.keys {
            grouped[key]?.sort { $0.startDate < $1.startDate }
        }
        eventsByDay = grouped
    }

    func events(on day: Date) -> [EKEvent] {
        eventsByDay[Calendar.current.startOfDay(for: day)] ?? []
    }
}
