import SwiftUI

struct LauncherModule: EdgeModule {
    let id = "launcher"
    let title = "Launcher"
    let iconName = "square.grid.3x3.fill"
    let supportsFullscreen = false

    var view: some View { LauncherView() }
}
