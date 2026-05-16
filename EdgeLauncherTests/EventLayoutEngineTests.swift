import XCTest
@testable import EdgeLauncher

final class EventLayoutEngineTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        return Calendar.current.date(from: c)!
    }

    private func makeEvent(title: String, start: Date, end: Date, allDay: Bool = false) -> TimelineEvent {
        TimelineEvent(
            source: .apple(calendarId: "cal"),
            calendarItemIdentifier: title,
            occurrenceStart: start,
            title: title,
            start: start,
            end: end,
            isAllDay: allDay
        )
    }

    func test_nonOverlapping_singleColumn() {
        let day = date(2026, 5, 15, 0)
        let winStart = date(2026, 5, 15, 6)
        let winEnd = date(2026, 5, 15, 22)
        _ = day
        let events = [
            makeEvent(title: "A", start: date(2026, 5, 15, 9), end: date(2026, 5, 15, 10)),
            makeEvent(title: "B", start: date(2026, 5, 15, 11), end: date(2026, 5, 15, 12))
        ]
        let placements = EventLayoutEngine.layout(events: events, windowStart: winStart, windowEnd: winEnd)
        XCTAssertEqual(placements.count, 2)
        for p in placements {
            XCTAssertEqual(p.column, 0)
            XCTAssertEqual(p.columnCount, 1)
        }
    }

    func test_overlapping_assignsColumns() {
        let winStart = date(2026, 5, 15, 6)
        let winEnd = date(2026, 5, 15, 22)
        let events = [
            makeEvent(title: "A", start: date(2026, 5, 15, 10), end: date(2026, 5, 15, 12)),
            makeEvent(title: "B", start: date(2026, 5, 15, 11), end: date(2026, 5, 15, 13))
        ]
        let placements = EventLayoutEngine.layout(events: events, windowStart: winStart, windowEnd: winEnd)
        XCTAssertEqual(placements.count, 2)
        let columns = placements.map(\.column).sorted()
        XCTAssertEqual(columns, [0, 1])
        for p in placements {
            XCTAssertEqual(p.columnCount, 2)
        }
    }

    func test_threeOverlappingEvents_assignsThreeColumns() {
        let winStart = date(2026, 5, 15, 6)
        let winEnd = date(2026, 5, 15, 22)
        let events = [
            makeEvent(title: "A", start: date(2026, 5, 15, 10), end: date(2026, 5, 15, 13)),
            makeEvent(title: "B", start: date(2026, 5, 15, 11), end: date(2026, 5, 15, 12)),
            makeEvent(title: "C", start: date(2026, 5, 15, 11, 30), end: date(2026, 5, 15, 12, 30))
        ]
        let placements = EventLayoutEngine.layout(events: events, windowStart: winStart, windowEnd: winEnd)
        XCTAssertEqual(placements.count, 3)
        XCTAssertTrue(placements.allSatisfy { $0.columnCount == 3 })
    }

    func test_truncatesStart_whenEventBeforeWindow() {
        let winStart = date(2026, 5, 15, 6)
        let winEnd = date(2026, 5, 15, 22)
        let events = [
            makeEvent(title: "Overnight", start: date(2026, 5, 14, 22), end: date(2026, 5, 15, 8))
        ]
        let placements = EventLayoutEngine.layout(events: events, windowStart: winStart, windowEnd: winEnd)
        XCTAssertEqual(placements.count, 1)
        XCTAssertTrue(placements[0].truncatedStart)
        XCTAssertFalse(placements[0].truncatedEnd)
    }

    func test_truncatesEnd_whenEventAfterWindow() {
        let winStart = date(2026, 5, 15, 6)
        let winEnd = date(2026, 5, 15, 22)
        let events = [
            makeEvent(title: "Late", start: date(2026, 5, 15, 20), end: date(2026, 5, 16, 2))
        ]
        let placements = EventLayoutEngine.layout(events: events, windowStart: winStart, windowEnd: winEnd)
        XCTAssertEqual(placements.count, 1)
        XCTAssertFalse(placements[0].truncatedStart)
        XCTAssertTrue(placements[0].truncatedEnd)
    }

    func test_excludesEventsCompletelyOutsideWindow() {
        let winStart = date(2026, 5, 15, 6)
        let winEnd = date(2026, 5, 15, 22)
        let events = [
            makeEvent(title: "EarlyDawn", start: date(2026, 5, 15, 3), end: date(2026, 5, 15, 5)),
            makeEvent(title: "PostMidnight", start: date(2026, 5, 15, 23), end: date(2026, 5, 16, 1))
        ]
        let placements = EventLayoutEngine.layout(events: events, windowStart: winStart, windowEnd: winEnd)
        XCTAssertEqual(placements.count, 0)
    }

    func test_allDayEvents_excludedFromTimedLayout() {
        let winStart = date(2026, 5, 15, 6)
        let winEnd = date(2026, 5, 15, 22)
        let events = [
            makeEvent(title: "Holiday", start: date(2026, 5, 15, 0), end: date(2026, 5, 16, 0), allDay: true),
            makeEvent(title: "Meeting", start: date(2026, 5, 15, 10), end: date(2026, 5, 15, 11))
        ]
        let placements = EventLayoutEngine.layout(events: events, windowStart: winStart, windowEnd: winEnd)
        XCTAssertEqual(placements.count, 1)
        XCTAssertEqual(placements[0].event.title, "Meeting")

        let allDay = EventLayoutEngine.allDayEvents(events)
        XCTAssertEqual(allDay.count, 1)
        XCTAssertEqual(allDay[0].title, "Holiday")
    }
}
