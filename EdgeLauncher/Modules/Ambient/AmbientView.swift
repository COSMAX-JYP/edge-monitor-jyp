import Combine
import SwiftUI

struct AmbientView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.06, green: 0.07, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 60) {
                Text(timeText)
                    .font(.system(size: 280, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                VStack(alignment: .leading, spacing: 12) {
                    Text(dateText)
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(dayText)
                        .font(.system(size: 28, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .onReceive(timer) { date in
            now = date
        }
    }

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: now)
    }

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일"
        return f.string(from: now)
    }

    private var dayText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "EEEE"
        return f.string(from: now)
    }
}
