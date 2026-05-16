import SwiftUI

struct ClockHero: View {
    let now: Date

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.18),
                    Color(red: 0.14, green: 0.18, blue: 0.28),
                    Color(red: 0.10, green: 0.12, blue: 0.20),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { _ in
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentColor.opacity(0.35), Color.purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 220, height: 220)
                        .blur(radius: 50)
                        .offset(x: CGFloat(i) * 320 - 100, y: CGFloat(i % 2 == 0 ? -40 : 40))
                }
            }

            HStack(spacing: 40) {
                Text(timeText)
                    .font(.system(size: 106, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .white.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color.accentColor.opacity(0.6), radius: 22)

                VStack(alignment: .leading, spacing: 10) {
                    Text(dateText)
                        .font(.system(size: 32, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                    Text(dayText)
                        .font(.system(size: 22, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    HStack(spacing: 12) {
                        statPill(label: "주", value: weekProgress)
                        statPill(label: "연", value: "\(dayOfYear)/365")
                    }
                    .padding(.top, 6)
                }

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .frame(height: 220)
    }

    private func statPill(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.appFootnoteBold).foregroundStyle(.white.opacity(0.55))
            Text(value).font(.appFootnoteMono).foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white.opacity(0.12), in: Capsule())
    }

    private var timeText: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: now)
    }
    private var dateText: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "yyyy년 M월 d일"; return f.string(from: now)
    }
    private var dayText: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "EEEE"; return f.string(from: now)
    }
    private var weekProgress: String {
        let wd = Calendar.current.component(.weekday, from: now)
        let mb = ((wd + 5) % 7) + 1
        return "\(mb)/7"
    }
    private var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0
    }
}
