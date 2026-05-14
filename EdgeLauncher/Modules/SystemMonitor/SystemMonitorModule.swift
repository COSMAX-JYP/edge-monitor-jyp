import SwiftUI

final class SystemMonitorModule: EdgeModule {
    let id = "system-monitor"
    let title = "Monitor"
    let iconName = "cpu"
    let supportsFullscreen = false

    static let stats = SystemStats()
    static let procs = ProcessStats()

    var view: some View { SystemMonitorView(stats: Self.stats, procs: Self.procs) }

    func didBecomeActive() {
        Self.stats.start()
        Self.procs.start()
    }

    func didResignActive() {
        Self.stats.stop()
        Self.procs.stop()
    }
}
