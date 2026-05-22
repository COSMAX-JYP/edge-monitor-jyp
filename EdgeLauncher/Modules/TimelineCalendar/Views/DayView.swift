import SwiftUI

struct DayView: View {
    @Bindable var viewModel: TimelineViewModel
    let day: Date
    let layout: VerticalRulerLayout
    private let timeColumnWidth: CGFloat = 56

    var body: some View {
        let dayEvents = events(on: day)
        let timed = dayEvents.filter { !$0.isAllDay }
        let allDay = dayEvents.filter { $0.isAllDay }
        let winStart = layout.windowStart(on: day)
        let winEnd = layout.windowEnd(on: day)
        let placements = EventLayoutEngine.layout(events: timed, windowStart: winStart, windowEnd: winEnd)

        return VStack(alignment: .leading, spacing: 0) {
            if !allDay.isEmpty {
                allDayBand(events: allDay)
                Divider()
            }
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            gridLines(width: geo.size.width)
                            timeLabels()
                            laneTapLayer(width: geo.size.width)
                            ForEach(placements, id: \.event.id) { placement in
                                eventBlock(placement: placement, totalWidth: geo.size.width)
                            }
                            nowIndicator(width: geo.size.width)
                        }
                        .frame(width: geo.size.width, height: layout.totalHeight, alignment: .topLeading)
                    }
                    .frame(height: layout.totalHeight)
                }
                .task(id: day) {
                    let targetHour = scrollTargetHour()
                    proxy.scrollTo("hour-\(targetHour)", anchor: .top)
                }
            }
        }
    }

    private func events(on day: Date) -> [TimelineEvent] {
        let cal = Calendar.current
        return viewModel.events.filter { cal.isDate($0.start, inSameDayAs: day) }
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

    private func gridLines(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.hourTicks(), id: \.self) { hour in
                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: max(0, width - timeColumnWidth), height: 0.5)
                    .offset(x: timeColumnWidth, y: yForHour(hour))
            }
        }
        .frame(width: width, height: layout.totalHeight, alignment: .topLeading)
    }

    private func laneTapLayer(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: max(0, width - timeColumnWidth), height: layout.totalHeight)
            .offset(x: timeColumnWidth, y: 0)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2)
                    .onEnded { value in
                        let snapped = snappedTime(y: value.location.y)
                        viewModel.startNewEvent(at: snapped)
                    }
            )
    }

    private func eventBlock(placement: EventLayoutEngine.Placement, totalWidth: CGFloat) -> some View {
        let event = placement.event
        let clampedStart = max(event.start, layout.windowStart(on: day))
        let clampedEnd = min(event.end, layout.windowEnd(on: day))
        let yStart = layout.y(for: clampedStart, on: day)
        let h = layout.height(from: clampedStart, to: clampedEnd, on: day)
        let color = blockColor(for: event)
        let laneWidth = max(0, totalWidth - timeColumnWidth - 8)
        let columnWidth = laneWidth / CGFloat(max(placement.columnCount, 1))
        let x = timeColumnWidth + 4 + columnWidth * CGFloat(placement.column)
        return TimelineEventBlock(placement: placement, baseColor: color)
            .frame(width: max(columnWidth - 4, 32), height: h)
            .offset(x: x, y: yStart)
            .onTapGesture { viewModel.showDetail(event) }
    }

    @ViewBuilder
    private func nowIndicator(width: CGFloat) -> some View {
        let now = Date()
        let cal = Calendar.current
        if cal.isDate(now, inSameDayAs: day) {
            let yPos = layout.y(for: now, on: day)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.red.opacity(0.85))
                    .frame(width: max(0, width - timeColumnWidth + 8), height: 1.5)
                    .offset(x: timeColumnWidth - 8, y: yPos)
                Circle().fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: timeColumnWidth - 4 - 4, y: yPos - 4)
            }
            .allowsHitTesting(false)
        }
    }

    private func yForHour(_ hour: Int) -> CGFloat {
        CGFloat(hour - layout.startHour) * layout.pixelsPerHour
    }

    private func snappedTime(y: CGFloat) -> Date {
        let raw = layout.date(at: y, on: day)
        let cal = Calendar.current
        let minute = cal.component(.minute, from: raw)
        let rounded = (minute / 15) * 15
        let hour = cal.component(.hour, from: raw)
        return cal.date(bySettingHour: hour, minute: rounded, second: 0, of: cal.startOfDay(for: day)) ?? raw
    }

    private func scrollTargetHour() -> Int {
        let cal = Calendar.current
        if cal.isDate(Date(), inSameDayAs: day) {
            let now = cal.component(.hour, from: Date())
            return max(layout.startHour, min(layout.endHour - 2, now - 1))
        }
        let firstEventHour = viewModel.events.first(where: { cal.isDate($0.start, inSameDayAs: day) && !$0.isAllDay }).map { cal.component(.hour, from: $0.start) }
        return firstEventHour ?? 8
    }

    private func blockColor(for event: TimelineEvent) -> Color {
        if let hex = event.colorHex, let parsed = Color.fromHex(hex) {
            return parsed
        }
        return .accentColor
    }

    private func allDayBand(events: [TimelineEvent]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(events, id: \.id) { event in
                    Text(event.title)
                        .font(.appFootnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1))
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.showDetail(event) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}
