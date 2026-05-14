import AppKit
import Combine
import Foundation

@MainActor
final class PomodoroStore: ObservableObject {
    enum Phase: String {
        case work = "집중"
        case shortBreak = "짧은 휴식"
        case longBreak = "긴 휴식"

        var duration: TimeInterval {
            switch self {
            case .work: return 25 * 60
            case .shortBreak: return 5 * 60
            case .longBreak: return 15 * 60
            }
        }

        var tint: String {
            switch self {
            case .work: return "tomato"
            case .shortBreak: return "mint"
            case .longBreak: return "indigo"
            }
        }
    }

    @Published var phase: Phase = .work
    @Published var remaining: TimeInterval = 25 * 60
    @Published var isRunning: Bool = false
    @Published var completedCycles: Int = 0

    private var timer: Timer?

    var progress: Double {
        guard phase.duration > 0 else { return 0 }
        return 1.0 - (remaining / phase.duration)
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        timer?.invalidate()
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func reset() {
        pause()
        remaining = phase.duration
    }

    func skip() {
        advance()
    }

    private func tick() {
        guard remaining > 0 else { advance(); return }
        remaining -= 1
        if remaining <= 0 {
            advance()
        }
    }

    private func advance() {
        pause()
        NSSound(named: "Glass")?.play()
        if phase == .work {
            completedCycles += 1
            phase = (completedCycles % 4 == 0) ? .longBreak : .shortBreak
        } else {
            phase = .work
        }
        remaining = phase.duration
    }
}
