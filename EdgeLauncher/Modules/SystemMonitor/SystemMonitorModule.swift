import SwiftUI

struct SystemMonitorModule: EdgeModule {
    let id = "system-monitor"
    let title = "Monitor"
    let iconName = "cpu"
    let supportsFullscreen = false

    var view: some View { SystemMonitorView() }
}
