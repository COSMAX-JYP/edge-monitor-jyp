import Combine
import SwiftUI

struct WidgetDashboardView: View {
    @ObservedObject var eventVM: EventStoreVM
    @ObservedObject var weather: WeatherService
    @State private var now = Date()
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
    }
}
