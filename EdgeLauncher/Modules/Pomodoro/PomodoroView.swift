import SwiftUI

struct PomodoroView: View {
    @ObservedObject var store: PomodoroStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Text(store.phase.rawValue)
                    .font(.system(size: 32, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 14)
                        .frame(width: 380, height: 380)

                    Circle()
                        .trim(from: 0, to: CGFloat(store.progress))
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .frame(width: 380, height: 380)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: store.progress)

                    Text(timeText)
                        .font(.system(size: 96, weight: .ultraLight, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                HStack(spacing: 16) {
                    Button(action: { store.reset() }) {
                        Label("리셋", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 110, height: 44)
                            .foregroundStyle(.white)
                            .background(.white.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: { store.toggle() }) {
                        Label(store.isRunning ? "일시정지" : "시작", systemImage: store.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 160, height: 52)
                            .foregroundStyle(.black)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: { store.skip() }) {
                        Label("건너뛰기", systemImage: "forward.fill")
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 110, height: 44)
                            .foregroundStyle(.white)
                            .background(.white.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Text("완료 사이클 \(store.completedCycles)회")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }

    private var timeText: String {
        let total = Int(max(0, store.remaining))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var gradientColors: [Color] {
        switch store.phase {
        case .work:
            return [Color(red: 0.85, green: 0.20, blue: 0.25), Color(red: 0.60, green: 0.10, blue: 0.30)]
        case .shortBreak:
            return [Color(red: 0.20, green: 0.55, blue: 0.50), Color(red: 0.10, green: 0.40, blue: 0.55)]
        case .longBreak:
            return [Color(red: 0.25, green: 0.30, blue: 0.65), Color(red: 0.10, green: 0.15, blue: 0.40)]
        }
    }
}
