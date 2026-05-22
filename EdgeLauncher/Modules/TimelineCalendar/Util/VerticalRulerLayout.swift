import Foundation
import CoreGraphics

struct VerticalRulerLayout: Equatable {
    let startHour: Int
    let endHour: Int
    let pixelsPerHour: CGFloat

    init(startHour: Int = 0, endHour: Int = 24, pixelsPerHour: CGFloat = 60) {
        self.startHour = max(0, min(startHour, 23))
        self.endHour = max(self.startHour + 1, min(endHour, 24))
        self.pixelsPerHour = max(pixelsPerHour, 24)
    }

    var totalHeight: CGFloat {
        CGFloat(endHour - startHour) * pixelsPerHour
    }

    func windowStart(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: calendar.startOfDay(for: day))
            ?? calendar.startOfDay(for: day)
    }

    func windowEnd(on day: Date, calendar: Calendar = .current) -> Date {
        let base = calendar.startOfDay(for: day)
        if endHour == 24 {
            return calendar.date(byAdding: .day, value: 1, to: base) ?? base
        }
        return calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: base) ?? base
    }

    func y(for date: Date, on day: Date, calendar: Calendar = .current) -> CGFloat {
        let start = windowStart(on: day, calendar: calendar)
        let secondsFromStart = date.timeIntervalSince(start)
        let raw = CGFloat(secondsFromStart) / 3600.0 * pixelsPerHour
        return min(max(raw, 0), totalHeight)
    }

    func height(from start: Date, to end: Date, on day: Date, calendar: Calendar = .current) -> CGFloat {
        let yStart = y(for: start, on: day, calendar: calendar)
        let yEnd = y(for: end, on: day, calendar: calendar)
        return max(yEnd - yStart, 16)
    }

    func date(at y: CGFloat, on day: Date, calendar: Calendar = .current) -> Date {
        let clamped = min(max(y, 0), totalHeight)
        let hoursFromStart = Double(clamped / pixelsPerHour)
        return windowStart(on: day, calendar: calendar).addingTimeInterval(hoursFromStart * 3600)
    }

    func hourTicks() -> [Int] {
        Array(startHour...endHour)
    }
}
