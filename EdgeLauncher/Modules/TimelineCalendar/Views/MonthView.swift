import SwiftUI

struct MonthView: View {
    @Bindable var viewModel: TimelineViewModel

    var body: some View {
        let grid = MonthView.makeGrid(for: viewModel.currentDay)
        VStack(spacing: 0) {
            weekdayHeader
            Divider()
            VStack(spacing: 0) {
                ForEach(0..<grid.weeks.count, id: \.self) { weekIndex in
                    HStack(spacing: 0) {
                        ForEach(grid.weeks[weekIndex], id: \.self) { day in
                            monthCell(day: day, isCurrentMonth: grid.isInCurrentMonth(day))
                                .frame(maxWidth: .infinity)
                            if day != grid.weeks[weekIndex].last { Divider() }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    if weekIndex != grid.weeks.count - 1 { Divider() }
                }
            }
        }
    }

    private var weekdayHeader: some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        let symbols = formatter.shortWeekdaySymbols ?? ["일", "월", "화", "수", "목", "금", "토"]
        return HStack(spacing: 0) {
            ForEach(symbols, id: \.self) { sym in
                Text(sym)
                    .font(.appCaptionBold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
    }

    private func monthCell(day: Date, isCurrentMonth: Bool) -> some View {
        let cal = Calendar.current
        let dayEvents = viewModel.events.filter { cal.isDate($0.start, inSameDayAs: day) }
        let preview = Array(dayEvents.prefix(3))
        let extraCount = max(0, dayEvents.count - preview.count)
        return Button {
            viewModel.setDay(day)
            viewModel.setViewMode(.day)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(dayNumberText(day))
                        .font(.appFootnoteBold)
                        .foregroundStyle(dayNumberColor(day: day, isCurrentMonth: isCurrentMonth))
                    Spacer()
                }
                ForEach(preview, id: \.id) { event in
                    Text(event.title)
                        .font(.appCaption)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(0.18)))
                }
                if extraCount > 0 {
                    Text("+\(extraCount)건")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(cal.isDateInToday(day) ? Color.accentColor.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func dayNumberText(_ day: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: day)
    }

    private func dayNumberColor(day: Date, isCurrentMonth: Bool) -> Color {
        if !isCurrentMonth { return .secondary.opacity(0.5) }
        if Calendar.current.isDateInToday(day) { return Color.accentColor }
        return .primary
    }

    // MARK: - Grid generator

    struct Grid {
        let monthStart: Date
        let weeks: [[Date]]
        func isInCurrentMonth(_ date: Date) -> Bool {
            Calendar.current.isDate(date, equalTo: monthStart, toGranularity: .month)
        }
    }

    static func makeGrid(for anchor: Date) -> Grid {
        var cal = Calendar.current
        cal.firstWeekday = 1
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: anchor)) else {
            return Grid(monthStart: anchor, weeks: [[anchor]])
        }
        let monthWeekday = cal.component(.weekday, from: monthStart) // 1=Sunday
        let leadingDays = monthWeekday - cal.firstWeekday
        let gridStart = cal.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart
        var weeks: [[Date]] = []
        for w in 0..<6 {
            var week: [Date] = []
            for d in 0..<7 {
                if let date = cal.date(byAdding: .day, value: w * 7 + d, to: gridStart) {
                    week.append(date)
                }
            }
            weeks.append(week)
        }
        return Grid(monthStart: monthStart, weeks: weeks)
    }
}
