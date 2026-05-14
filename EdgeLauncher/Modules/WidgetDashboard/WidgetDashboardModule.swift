import SwiftUI

final class WidgetDashboardModule: EdgeModule {
    let id = "widgets"
    let title = "Widgets"
    let iconName = "rectangle.grid.2x2"
    let supportsFullscreen = false

    static let eventVM = EventStoreVM()
    static let weather = WeatherService()

    var view: some View {
        WidgetDashboardView(eventVM: Self.eventVM, weather: Self.weather)
    }

    func didBecomeActive() {
        Task { await Self.eventVM.requestAccess() }
        Self.weather.start()
    }

    func didResignActive() {
        Self.weather.stop()
    }
}
