import Foundation
import CoreGraphics

struct TimeRulerLayout: Equatable {
    let startHour: Int
    let endHour: Int
    let totalWidth: CGFloat

    init(startHour: Int = 6, endHour: Int = 22, totalWidth: CGFloat = 2370) {
        self.startHour = max(0, min(startHour, 23))
        self.endHour = max(self.startHour + 1, min(endHour, 24))
        self.totalWidth = max(totalWidth, 1)
    }

    var hourWidth: CGFloat {
        totalWidth / CGFloat(endHour - startHour)
    }

    func startOfDay(_ day: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: day)
    }

    func windowStart(on day: Date, calendar: Calendar = .current) -> Date {
        let cal = calendar
        return cal.date(bySettingHour: startHour, minute: 0, second: 0, of: cal.startOfDay(for: day))
            ?? cal.startOfDay(for: day)
    }

    func windowEnd(on day: Date, calendar: Calendar = .current) -> Date {
        let cal = calendar
        let baseStart = cal.startOfDay(for: day)
        if endHour == 24 {
            return cal.date(byAdding: .day, value: 1, to: baseStart) ?? baseStart
        }
        return cal.date(bySettingHour: endHour, minute: 0, second: 0, of: baseStart) ?? baseStart
    }

    func x(for date: Date, on day: Date, calendar: Calendar = .current) -> CGFloat {
        let winStart = windowStart(on: day, calendar: calendar)
        let secondsFromStart = date.timeIntervalSince(winStart)
        let secondsPerHour: CGFloat = 3600
        let raw = CGFloat(secondsFromStart) / secondsPerHour * hourWidth
        return min(max(raw, 0), totalWidth)
    }

    func width(from start: Date, to end: Date, on day: Date, calendar: Calendar = .current) -> CGFloat {
        let xStart = x(for: start, on: day, calendar: calendar)
        let xEnd = x(for: end, on: day, calendar: calendar)
        return max(xEnd - xStart, 2)
    }

    func date(at x: CGFloat, on day: Date, calendar: Calendar = .current) -> Date {
        let clamped = min(max(x, 0), totalWidth)
        let hoursFromStart = Double(clamped / hourWidth)
        let winStart = windowStart(on: day, calendar: calendar)
        return winStart.addingTimeInterval(hoursFromStart * 3600)
    }

    func hourTicks() -> [Int] {
        Array(startHour...endHour)
    }
}
