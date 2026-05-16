import SwiftUI

struct NowIndicatorView: View {
    let layout: TimeRulerLayout
    let day: Date
    @State private var now: Date = Date()
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsIndicator {
                let xPos = layout.x(for: now, on: day)
                Rectangle()
                    .fill(Color.red.opacity(0.75))
                    .frame(width: 1.5)
                    .offset(x: xPos)
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
                    .offset(x: xPos - 3.5, y: -3.5)
                Text(timeLabel)
                    .font(.appCaptionMono)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.background.opacity(0.85))
                    .clipShape(Capsule())
                    .offset(x: xPos + 6, y: -8)
            }
        }
        .task {
            now = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if Task.isCancelled { return }
                now = Date()
            }
        }
    }

    private var showsIndicator: Bool {
        let cal = Calendar.current
        guard cal.isDate(now, inSameDayAs: day) else { return false }
        let winStart = layout.windowStart(on: day)
        let winEnd = layout.windowEnd(on: day)
        return now >= winStart && now <= winEnd
    }

    private var timeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: now)
    }
}
