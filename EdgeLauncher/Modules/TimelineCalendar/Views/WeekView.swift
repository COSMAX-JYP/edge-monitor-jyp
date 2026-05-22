import SwiftUI

struct WeekView: View {
    @Bindable var viewModel: TimelineViewModel
    let layout: VerticalRulerLayout
    private let timeColumnWidth: CGFloat = 56

    var body: some View {
        let days = viewModel.visibleDays(from: viewModel.currentDay, mode: .week)
        return VStack(spacing: 0) {
            weekHeader(days: days)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    GeometryReader { geo in
                        let dayWidth = max(0, (geo.size.width - timeColumnWidth) / CGFloat(days.count))
                        ZStack(alignment: .topLeading) {
                            timeLabels()
                            ForEach(Array(days.enumerated()), id: \.element) { idx, day in
                                dayColumn(day: day, x: timeColumnWidth + CGFloat(idx) * dayWidth, width: dayWidth)
                            }
                        }
                        .frame(width: geo.size.width, height: layout.totalHeight, alignment: .topLeading)
                    }
                    .frame(height: layout.totalHeight)
                }
                .task(id: viewModel.currentDay) {
                    let target = scrollTargetHour()
                    proxy.scrollTo("hour-\(target)", anchor: .top)
                }
            }
        }
    }

    private func weekHeader(days: [Date]) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeColumnWidth)
            ForEach(days, id: \.self) { day in
                Button {
                    viewModel.setDay(day)
                    viewModel.setViewMode(.day)
                } label: {
                    VStack(spacing: 1) {
                        Text(weekdayText(day))
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                        Text(dayText(day))
                            .font(.appBodyBold)
                            .foregroundStyle(isToday(day) ? Color.accentColor : Color.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                if day != days.last { Divider() }
            }
        }
    }

    private func timeLabels() -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.hourTicks(), id: \.self) { hour in
                Text(String(format: "%02d", hour % 24))
                    .font(.appCaptionMono)
                    .foregroundStyle(.secondary)
                    .frame(width: timeColumnWidth - 8, alignment: .trailing)
                    .position(x: (timeColumnWidth - 8) / 2, y: yForHour(hour))
                    .id("hour-\(hour)")
            }
        }
        .frame(width: timeColumnWidth, height: layout.totalHeight, alignment: .topLeading)
    }

    private func dayColumn(day: Date, x: CGFloat, width: CGFloat) -> some View {
        let cal = Calendar.current
        let dayEvents = viewModel.events.filter { cal.isDate($0.start, inSameDayAs: day) && !$0.isAllDay }
        let winStart = layout.windowStart(on: day)
        let winEnd = layout.windowEnd(on: day)
        let placements = EventLayoutEngine.layout(events: dayEvents, windowStart: winStart, windowEnd: winEnd)
        return ZStack(alignment: .topLeading) {
            // grid lines
            ForEach(layout.hourTicks(), id: \.self) { hour in
                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: width, height: 0.5)
                    .offset(x: 0, y: yForHour(hour))
            }
            // tap layer
            Rectangle()
                .fill(Color.clear)
                .frame(width: width, height: layout.totalHeight)
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture(count: 2)
                        .onEnded { value in
                            let snapped = snappedTime(y: value.location.y, day: day)
                            viewModel.startNewEvent(at: snapped)
                        }
                )
            // events
            ForEach(placements, id: \.event.id) { placement in
                eventBlock(placement: placement, day: day, totalWidth: width)
            }
            // now
            if cal.isDate(Date(), inSameDayAs: day) {
                let yPos = layout.y(for: Date(), on: day)
                Rectangle()
                    .fill(Color.red.opacity(0.85))
                    .frame(width: width, height: 1.5)
                    .offset(x: 0, y: yPos)
            }
            // right divider
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 0.5, height: layout.totalHeight)
                .offset(x: width, y: 0)
        }
        .frame(width: width, height: layout.totalHeight, alignment: .topLeading)
        .offset(x: x, y: 0)
    }

    private func eventBlock(placement: EventLayoutEngine.Placement, day: Date, totalWidth: CGFloat) -> some View {
        let event = placement.event
        let clampedStart = max(event.start, layout.windowStart(on: day))
        let clampedEnd = min(event.end, layout.windowEnd(on: day))
        let yStart = layout.y(for: clampedStart, on: day)
        let h = layout.height(from: clampedStart, to: clampedEnd, on: day)
        let color = blockColor(for: event)
        let columnWidth = max(0, (totalWidth - 4) / CGFloat(max(placement.columnCount, 1)))
        let x = 2 + columnWidth * CGFloat(placement.column)
        return TimelineEventBlock(placement: placement, baseColor: color)
            .frame(width: max(columnWidth - 2, 32), height: h)
            .offset(x: x, y: yStart)
            .onTapGesture { viewModel.showDetail(event) }
    }

    private func yForHour(_ hour: Int) -> CGFloat {
        CGFloat(hour - layout.startHour) * layout.pixelsPerHour
    }

    private func snappedTime(y: CGFloat, day: Date) -> Date {
        let raw = layout.date(at: y, on: day)
        let cal = Calendar.current
        let minute = cal.component(.minute, from: raw)
        let rounded = (minute / 15) * 15
        let hour = cal.component(.hour, from: raw)
        return cal.date(bySettingHour: hour, minute: rounded, second: 0, of: cal.startOfDay(for: day)) ?? raw
    }

    private func scrollTargetHour() -> Int {
        let cal = Calendar.current
        let now = Date()
        let isThisWeek = viewModel.visibleDays(from: viewModel.currentDay, mode: .week)
            .contains(where: { cal.isDate($0, inSameDayAs: now) })
        if isThisWeek {
            let hour = cal.component(.hour, from: now)
            return max(layout.startHour, min(layout.endHour - 2, hour - 1))
        }
        return 8
    }

    private func blockColor(for event: TimelineEvent) -> Color {
        if let hex = event.colorHex, let parsed = Color.fromHex(hex) {
            return parsed
        }
        return .accentColor
    }

    private func weekdayText(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "E"
        return f.string(from: day)
    }

    private func dayText(_ day: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: day)
    }

    private func isToday(_ day: Date) -> Bool {
        Calendar.current.isDateInToday(day)
    }
}
