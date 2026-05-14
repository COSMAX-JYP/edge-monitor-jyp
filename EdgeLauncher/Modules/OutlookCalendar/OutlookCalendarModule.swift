import SwiftUI

struct OutlookCalendarModule: EdgeModule {
    let id = "outlook-calendar"
    let title = "연차계획"
    let iconName = "calendar.badge.clock"
    let supportsFullscreen = true

    var view: some View { OutlookCalendarView() }
}
