import SwiftUI

struct TimelineRulerView: View {
    let layout: TimeRulerLayout

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(layout.hourTicks(), id: \.self) { hour in
                    let isStart = hour == layout.startHour
                    let isEnd = hour == layout.endHour
                    let x = CGFloat(hour - layout.startHour) * layout.hourWidth
                    Rectangle()
                        .fill(Color.secondary.opacity(isStart || isEnd ? 0.4 : 0.15))
                        .frame(width: 0.5, height: proxy.size.height)
                        .offset(x: x)
                    Text(label(for: hour))
                        .font(.appFootnoteMono)
                        .foregroundStyle(.secondary)
                        .offset(x: x + 6, y: 2)
                }
            }
        }
    }

    private func label(for hour: Int) -> String {
        String(format: "%02d", hour % 24)
    }
}
