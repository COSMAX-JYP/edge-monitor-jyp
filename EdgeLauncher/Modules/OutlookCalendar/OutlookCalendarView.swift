import EventKit
import SwiftUI

struct OutlookCalendarView: View {
    @StateObject private var store = MonthEventStore()
    @State private var currentMonth: Date = Calendar.current.startOfMonth(for: Date())

    private let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(spacing: 0) {
            header
            weekdayHeader
            grid
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.07))
        .task { await store.requestAccess(); store.reload(for: currentMonth) }
        .onChange(of: currentMonth) { _, m in store.reload(for: m) }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(monthTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button(action: prevMonth) {
                Image(systemName: "chevron.left").font(.appBodyBold)
                    .frame(width: 44, height: 32)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button("오늘") {
                currentMonth = Calendar.current.startOfMonth(for: Date())
            }
            .buttonStyle(.plain)
            .font(.appBody)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .foregroundStyle(.white)
            .background(.white.opacity(0.1), in: Capsule())

            Button(action: nextMonth) {
                Image(systemName: "chevron.right").font(.appBodyBold)
                    .frame(width: 44, height: 32)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button(action: { store.reload(for: currentMonth) }) {
                Image(systemName: "arrow.clockwise").font(.appFootnote)
                    .frame(width: 44, height: 32)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { idx in
                Text(weekdayNames[idx])
                    .font(.appFootnoteBold)
                    .foregroundStyle(idx == 0 ? Color.red.opacity(0.85)
                                       : (idx == 6 ? Color.blue.opacity(0.85)
                                                   : Color.white.opacity(0.5)))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 18, weight: isToday ? .bold : .regular, design: .rounded))
                    .foregroundStyle(textColor)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(isToday ? Color.white : Color.clear)
                    )
                    .foregroundStyle(isToday ? Color.black : textColor)

                Text(secondaryDateText)
                    .font(.appCaptionMono)
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(events.prefix(4).enumerated()), id: \.element.eventIdentifier) { _, event in
                    eventChip(event)
                }
                if events.count > 4 {
                    Text("+\(events.count - 4)")
                        .font(.appCaptionMono)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.leading, 8)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(isInCurrentMonth ? 1.0 : 0.35)
        .background(isToday ? Color.white.opacity(0.05) : Color.clear)
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func eventChip(_ event: EKEvent) -> some View {
        let color = Color(cgColor: event.calendar?.cgColor ?? CGColor(red: 0.4, green: 0.6, blue: 1, alpha: 1))
        return Text(event.title ?? "")
            .font(.appCaption)
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.85))
            .cornerRadius(4)
            .padding(.horizontal, 5)
    }

    private var secondaryDateText: String {
        let m = Calendar.current.component(.month, from: date)
        let d = Calendar.current.component(.day, from: date)
        return String(format: "%d/%d", m, d)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isInCurrentMonth: Bool {
        Calendar.current.component(.month, from: date) == Calendar.current.component(.month, from: currentMonth)
    }

    private var textColor: Color {
        let weekday = Calendar.current.component(.weekday, from: date)
        if weekday == 1 { return Color.red.opacity(0.85) }
        if weekday == 7 { return Color.blue.opacity(0.85) }
        return .white
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
