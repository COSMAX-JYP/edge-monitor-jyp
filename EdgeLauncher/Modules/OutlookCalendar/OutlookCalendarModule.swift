import SwiftUI

struct OutlookCalendarModule: EdgeModule {
    let id = "outlook-calendar"
    let title = "Outlook"
    let iconName = "calendar.badge.clock"
    let supportsFullscreen = true

    var view: some View { OutlookCalendarView() }
}
