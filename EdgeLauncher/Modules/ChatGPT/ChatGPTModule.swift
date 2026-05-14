import SwiftUI

struct ChatGPTModule: EdgeModule {
    let id = "chatgpt"
    let title = "ChatGPT"
    let iconName = "sparkle"
    let supportsFullscreen = true

    var view: some View { ChatGPTView() }
}
