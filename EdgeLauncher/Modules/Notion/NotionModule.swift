import SwiftUI

struct NotionModule: EdgeModule {
    let id = "notion"
    let title = "Notion"
    let iconName = "doc.text.fill"
    let supportsFullscreen = true

    var view: some View { NotionView() }
}
