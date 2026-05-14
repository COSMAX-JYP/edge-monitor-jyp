import SwiftUI

struct MessengerModule: EdgeModule {
    let id = "messenger"
    let title = "Discord"
    let iconName = "bubble.left.and.bubble.right.fill"
    let supportsFullscreen = true

    var view: some View { MessengerView() }
}
