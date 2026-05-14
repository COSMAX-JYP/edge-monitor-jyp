import SwiftUI

struct YouTubeMusicModule: EdgeModule {
    let id = "youtube-music"
    let title = "Music"
    let iconName = "music.note"
    let supportsFullscreen = true

    var view: some View { YouTubeMusicView() }
}
