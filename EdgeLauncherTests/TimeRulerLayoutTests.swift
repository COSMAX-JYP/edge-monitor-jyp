import XCTest
@testable import EdgeLauncher

final class TimeRulerLayoutTests: XCTestCase {

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        return Calendar.current.date(from: c)!
    }

    func test_hourWidth_isTotalDividedByRange() {
        let layout = TimeRulerLayout(startHour: 6, endHour: 22, totalWidth: 1600)
        XCTAssertEqual(layout.hourWidth, 100, accuracy: 0.001)
    }

    func test_x_atStartHourIsZero() {
        let layout = TimeRulerLayout(startHour: 6, endHour: 22, totalWidth: 1600)
        let d = day(2026, 5, 15)
        let start = date(2026, 5, 15, 6, 0)
        XCTAssertEqual(layout.x(for: start, on: d), 0, accuracy: 0.001)
    }

    func test_x_atMiddleHour() {
        let layout = TimeRulerLayout(startHour: 6, endHour: 22, totalWidth: 1600)
        let d = day(2026, 5, 15)
        let mid = date(2026, 5, 15, 14, 0)
        XCTAssertEqual(layout.x(for: mid, on: d), 800, accuracy: 0.001)
    }

    func test_x_atEndHour() {
        let layout = TimeRulerLayout(startHour: 6, endHour: 22, totalWidth: 1600)
        let d = day(2026, 5, 15)
        let end = date(2026, 5, 15, 22, 0)
        XCTAssertEqual(layout.x(for: end, on: d), 1600, accuracy: 0.001)
    }

    func test_x_clampsBelowWindow() {
        let layout = TimeRulerLayout(startHour: 6, endHour: 22, totalWidth: 1600)
        let d = day(2026, 5, 15)
        let early = date(2026, 5, 15, 3, 0)
        XCTAssertEqual(layout.x(for: early, on: d), 0, accuracy: 0.001)
    }

    func test_x_clampsAboveWindow() {
        let layout = TimeRulerLayout(startHour: 6, endHour: 22, totalWidth: 1600)
        let d = day(2026, 5, 15)
        let late = date(2026, 5, 15, 23, 30)
        XCTAssertEqual(layout.x(for: late, on: d), 1600, accuracy: 0.001)
    }

    func test_dateAt_isInverseOfX() {
        let layout = TimeRulerLayout(startHour: 6, endHour: 22, totalWidth: 1600)
        let d = day(2026, 5, 15)
        let target = date(2026, 5, 15, 12, 30)
        let xPos = layout.x(for: target, on: d)
        let roundTrip = layout.date(at: xPos, on: d)
        XCTAssertEqual(roundTrip.timeIntervalSince(target), 0, accuracy: 1)
    }

    func test_width_betweenTwoTimes() {
        let layout = TimeRulerLayout(startHour: 6, endHour: 22, totalWidth: 1600)
        let d = day(2026, 5, 15)
        let s = date(2026, 5, 15, 10, 0)
        let e = date(2026, 5, 15, 12, 0)
        XCTAssertEqual(layout.width(from: s, to: e, on: d), 200, accuracy: 0.001)
    }

    func test_hourTicks_listsAllInclusive() {
        let layout = TimeRulerLayout(startHour: 6, endHour: 10, totalWidth: 400)
        XCTAssertEqual(layout.hourTicks(), [6, 7, 8, 9, 10])
    }
}
