import EventKit
import SwiftUI

struct OutlookCalendarView: View {
    @StateObject private var store = MonthEventStore()
    @State private var currentMonth: Date = Calendar.current.startOfMonth(for: Date())

    private let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            weekdayHeader
            Divider()
            grid
        }
        .background(Color(NSColor.windowBackgroundColor))
        .task { await store.requestAccess(); store.reload(for: currentMonth) }
        .onChange(of: currentMonth) { _, m in store.reload(for: m) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(monthTitle)
                .font(.system(size: 22, weight: .semibold))

            Spacer()

            Button(action: prevMonth) {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .help("이전 달")

            Button("오늘") {
                currentMonth = Calendar.current.startOfMonth(for: Date())
            }
            .buttonStyle(.bordered)

            Button(action: nextMonth) {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .help("다음 달")

            Button(action: { store.reload(for: currentMonth) }) {
                Image(systemName: "arrow.clockwise").font(.system(size: 13))
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .help("새로고침")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { idx in
                Text(weekdayNames[idx])
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(idx == 0 ? Color.red : (idx == 6 ? Color.blue : Color.secondary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .background(.regularMaterial.opacity(0.5))
    }

    private var grid: some View {
        GeometryReader { geo in
            let days = computeDays()
            let rows = 6
            let cols = 7
            let cellW = geo.size.width / CGFloat(cols)
            let cellH = geo.size.height / CGFloat(rows)
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<cols, id: \.self) { c in
                            let day = days[r * cols + c]
                            DayCell(date: day, currentMonth: currentMonth, events: store.events(on: day))
                                .frame(width: cellW, height: cellH)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
        }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        return f.string(from: currentMonth)
    }

    private func prevMonth() {
        if let d = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = Calendar.current.startOfMonth(for: d)
        }
    }

    private func nextMonth() {
        if let d = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = Calendar.current.startOfMonth(for: d)
        }
    }

    private func computeDays() -> [Date] {
        let cal = Calendar.current
        guard let monthStart = cal.dateInterval(of: .month, for: currentMonth)?.start else { return [] }
        let weekday = cal.component(.weekday, from: monthStart)
        let gridStart = cal.date(byAdding: .day, value: -(weekday - 1), to: monthStart) ?? monthStart
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }
}

private struct DayCell: View {
    let date: Date
    let currentMonth: Date
    let events: [EKEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 12, weight: isToday ? .bold : .medium, design: .monospaced))
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Circle()
                            .fill(isToday ? Color.accentColor : Color.clear)
                            .frame(width: 22, height: 22)
                    )
                    .foregroundStyle(isToday ? Color.white : textColor)
                Spacer()
                if events.count > 3 {
                    Text("+\(events.count - 3)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            ForEach(Array(events.prefix(3).enumerated()), id: \.element.eventIdentifier) { _, event in
                eventChip(event)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(isInCurrentMonth ? 1.0 : 0.35)
        .background(isToday ? Color.accentColor.opacity(0.05) : Color.clear)
    }

    private func eventChip(_ event: EKEvent) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(Color(cgColor: event.calendar?.cgColor ?? CGColor(red: 0.4, green: 0.6, blue: 1, alpha: 1)))
                .frame(width: 3)
            Text(event.title ?? "")
                .font(.system(size: 10))
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            (Color(cgColor: event.calendar?.cgColor ?? CGColor(red: 0.4, green: 0.6, blue: 1, alpha: 1)))
                .opacity(0.15)
        )
        .cornerRadius(3)
        .padding(.horizontal, 2)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isInCurrentMonth: Bool {
        Calendar.current.component(.month, from: date) == Calendar.current.component(.month, from: currentMonth)
    }

    private var textColor: Color {
        let weekday = Calendar.current.component(.weekday, from: date)
        if weekday == 1 { return .red }
        if weekday == 7 { return .blue }
        return .primary
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
