import SwiftUI

struct ClaudeModule: EdgeModule {
    let id = "claude"
    let title = "Claude"
    let iconName = "brain"
    let supportsFullscreen = true

    var view: some View { ClaudeView() }
}
