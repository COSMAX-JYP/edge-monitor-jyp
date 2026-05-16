import SwiftUI

struct YouTubeModule: EdgeModule {
    let id = "youtube"
    let title = "YouTube"
    let iconName = "play.rectangle.fill"
    let supportsFullscreen = true
    let preservesInactiveRendering = true

    var view: some View { YouTubeView() }
}
