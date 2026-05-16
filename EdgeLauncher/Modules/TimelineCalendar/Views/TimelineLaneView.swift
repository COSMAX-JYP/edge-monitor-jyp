import SwiftUI

struct TimelineLaneView: View {
    let placements: [EventLayoutEngine.Placement]
    let layout: TimeRulerLayout
    let day: Date
    let baseColor: Color
    let laneHeight: CGFloat
    var onTapEvent: (TimelineEvent) -> Void = { _ in }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(placements, id: \.event.id) { placement in
                let block = blockFrame(placement: placement)
                TimelineEventBlock(placement: placement, baseColor: color(for: placement))
                    .frame(width: block.width, height: block.height)
                    .offset(x: block.x, y: block.y)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapEvent(placement.event) }
            }
        }
        .frame(height: laneHeight)
    }

    private func blockFrame(placement: EventLayoutEngine.Placement) -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let event = placement.event
        let winStart = layout.windowStart(on: day)
        let winEnd = layout.windowEnd(on: day)
        let clampedStart = max(event.start, winStart)
        let clampedEnd = min(event.end, winEnd)
        let xStart = layout.x(for: clampedStart, on: day)
        let xEnd = layout.x(for: clampedEnd, on: day)
        let width = max(xEnd - xStart, 24)
        let inset: CGFloat = 4
        let usable = laneHeight - inset * 2
        let columnHeight = usable / CGFloat(max(placement.columnCount, 1))
        let y = inset + CGFloat(placement.column) * columnHeight
        return (x: xStart, y: y, width: width, height: max(columnHeight - 2, 18))
    }

    private func color(for placement: EventLayoutEngine.Placement) -> Color {
        if let hex = placement.event.colorHex, let parsed = Color.fromHex(hex) {
            return parsed
        }
        return baseColor
    }
}

extension Color {
    static func fromHex(_ hex: String) -> Color? {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
