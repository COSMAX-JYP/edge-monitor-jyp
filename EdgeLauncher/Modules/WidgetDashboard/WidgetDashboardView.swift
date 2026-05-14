import Combine
import SwiftUI

struct WidgetDashboardView: View {
    @State private var now = Date()
    @StateObject private var eventVM = EventStoreVM()
    @StateObject private var weather = WeatherService()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ClockHero(now: now)
            Divider()
            HStack(spacing: 0) {
                WeatherPanel(weather: weather).frame(width: 320)
                Divider()
                OutlookPanel(eventVM: eventVM)
                Divider()
                RemindersPanel(eventVM: eventVM)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(timer) { now = $0 }
        .task {
            await eventVM.requestAccess()
            weather.start()
        }
    }
}
