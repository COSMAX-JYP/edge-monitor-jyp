import SwiftUI

struct YouTubeMusicModule: EdgeModule {
    let id = "youtube-music"
    let title = "Music"
    let iconName = "music.note"
    let supportsFullscreen = true
    let preservesInactiveRendering = true

    var view: some View { YouTubeMusicView() }
}
