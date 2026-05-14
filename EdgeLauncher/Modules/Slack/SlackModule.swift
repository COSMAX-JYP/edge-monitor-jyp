import SwiftUI

struct SlackModule: EdgeModule {
    let id = "slack"
    let title = "Slack"
    let iconName = "number"
    let supportsFullscreen = true

    var view: some View { SlackView() }
}
