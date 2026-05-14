import SwiftUI

final class PomodoroModule: EdgeModule {
    let id = "pomodoro"
    let title = "Pomodoro"
    let iconName = "timer"
    let supportsFullscreen = true

    static let store = PomodoroStore()

    var view: some View { PomodoroView(store: Self.store) }

    func didBecomeActive() {}
    func didResignActive() {}
}
