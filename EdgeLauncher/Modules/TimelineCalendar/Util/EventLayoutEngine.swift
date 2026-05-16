import Foundation

struct EventLayoutEngine {
    struct Placement: Hashable {
        let event: TimelineEvent
        let column: Int
        let columnCount: Int
        let truncatedStart: Bool
        let truncatedEnd: Bool
    }

    static func layout(
        events: [TimelineEvent],
        windowStart: Date,
        windowEnd: Date
    ) -> [Placement] {
        let timed = events.filter { !$0.isAllDay }
        let clamped: [(event: TimelineEvent, truncStart: Bool, truncEnd: Bool)] = timed.compactMap { event in
            guard event.end > windowStart, event.start < windowEnd else { return nil }
            let truncStart = event.start < windowStart
            let truncEnd = event.end > windowEnd
            return (event, truncStart, truncEnd)
        }
        let sorted = clamped.sorted { $0.event.start < $1.event.start }

        var placements: [Placement] = []
        var currentGroup: [(event: TimelineEvent, truncStart: Bool, truncEnd: Bool, column: Int)] = []
        var groupEnd: Date = .distantPast

        func flush() {
            guard !currentGroup.isEmpty else { return }
            let count = (currentGroup.map { $0.column }.max() ?? 0) + 1
            for item in currentGroup {
                placements.append(Placement(
                    event: item.event,
                    column: item.column,
                    columnCount: count,
                    truncatedStart: item.truncStart,
                    truncatedEnd: item.truncEnd
                ))
            }
            currentGroup.removeAll(keepingCapacity: true)
        }

        for item in sorted {
            let visibleStart = max(item.event.start, windowStart)
            if visibleStart >= groupEnd {
                flush()
                groupEnd = min(item.event.end, windowEnd)
                currentGroup.append((item.event, item.truncStart, item.truncEnd, 0))
                continue
            }
            let usedColumns = Set(currentGroup
                .filter { max($0.event.start, windowStart) < min(item.event.end, windowEnd)
                       && visibleStart < min($0.event.end, windowEnd) }
                .map { $0.column })
            var column = 0
            while usedColumns.contains(column) { column += 1 }
            currentGroup.append((item.event, item.truncStart, item.truncEnd, column))
            groupEnd = max(groupEnd, min(item.event.end, windowEnd))
        }
        flush()
        return placements
    }

    static func allDayEvents(_ events: [TimelineEvent]) -> [TimelineEvent] {
        events.filter { $0.isAllDay }
    }
}
