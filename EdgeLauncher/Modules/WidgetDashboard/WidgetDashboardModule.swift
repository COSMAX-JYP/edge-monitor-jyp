import SwiftUI

struct WidgetDashboardModule: EdgeModule {
    let id = "widgets"
    let title = "Widgets"
    let iconName = "rectangle.grid.2x2"
    let supportsFullscreen = false

    var view: some View { WidgetDashboardView() }
}
