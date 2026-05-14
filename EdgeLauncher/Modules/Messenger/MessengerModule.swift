import SwiftUI

struct MessengerModule: EdgeModule {
    let id = "messenger"
    let title = "Inbox"
    let iconName = "bubble.left.and.bubble.right"
    let supportsFullscreen = false

    var view: some View { MessengerView() }
}
