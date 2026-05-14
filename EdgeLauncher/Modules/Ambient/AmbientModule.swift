import SwiftUI

struct AmbientModule: EdgeModule {
    let id = "ambient"
    let title = "Ambient"
    let iconName = "moon.stars"
    let supportsFullscreen = true

    var view: some View { AmbientView() }
}
