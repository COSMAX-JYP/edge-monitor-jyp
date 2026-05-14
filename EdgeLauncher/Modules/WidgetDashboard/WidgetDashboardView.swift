import Combine
import EventKit
import SwiftUI

struct WidgetDashboardView: View {
    @State private var now = Date()
    @StateObject private var eventVM = EventStoreVM()
    @StateObject private var weather = WeatherService()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            clockHero
            Divider()
            HStack(spacing: 0) {
                weatherPanel
                    .frame(width: 320)
                Divider()
                outlookPanel
                Divider()
                remindersPanel
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(timer) { now = $0 }
        .task {
            await eventVM.requestAccess()
            weather.start()
        }
    }

    // MARK: - 시간/날짜 hero

    private var clockHero: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.18),
                    Color(red: 0.14, green: 0.18, blue: 0.28),
                    Color(red: 0.10, green: 0.12, blue: 0.20),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geo in
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentColor.opacity(0.35), Color.purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 220, height: 220)
                        .blur(radius: 50)
                        .offset(x: CGFloat(i) * 320 - 100, y: CGFloat(i % 2 == 0 ? -40 : 40))
                }
            }

            HStack(spacing: 40) {
                Text(timeText)
                    .font(.system(size: 132, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.accentColor.opacity(0.6), radius: 22)

                VStack(alignment: .leading, spacing: 10) {
                    Text(dateText)
                        .font(.system(size: 32, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                    Text(dayText)
                        .font(.system(size: 24, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    HStack(spacing: 12) {
                        statPill(label: "주", value: weekProgress)
                        statPill(label: "연", value: "\(dayOfYear)/365")
                    }
                    .padding(.top, 6)
                }

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .frame(height: 220)
    }

    private func statPill(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.12), in: Capsule())
    }

    // MARK: - 날씨

    private var weatherPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("날씨", systemImage: "cloud.sun.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.multicolor)
                Spacer()
                if let updated = weather.lastUpdated {
                    Text(relativeUpdate(updated))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            if !weather.hasLocationAccess {
                weatherPermission
            } else if weather.snapshot.weatherCode < 0 {
                ProgressView("로딩 중...")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                weatherBody
            }

            Spacer()

            if let err = weather.errorMessage {
                Text(err).font(.system(size: 10)).foregroundStyle(.red)
            }
            Text("Open-Meteo + Apple CoreLocation")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var weatherBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(weather.snapshot.locationName.isEmpty ? "현재 위치" : weather.snapshot.locationName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Image(systemName: weather.snapshot.icon)
                    .font(.system(size: 56))
                    .symbolRenderingMode(.multicolor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.0f°", weather.snapshot.temperature))
                        .font(.system(size: 48, weight: .ultraLight))
                        .monospacedDigit()
                    Text(weather.snapshot.description)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 6) {
                weatherStat(icon: "thermometer.medium", label: "체감", value: String(format: "%.0f°", weather.snapshot.feelsLike))
                weatherStat(icon: "humidity.fill", label: "습도", value: "\(weather.snapshot.humidity)%")
                weatherStat(icon: "wind", label: "바람", value: String(format: "%.1f m/s", weather.snapshot.windSpeed))
                weatherStat(icon: "sun.max.fill", label: "UV", value: String(format: "%.1f", weather.snapshot.uvIndex))
            }
        }
    }

    private var weatherPermission: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("위치 권한이 필요합니다", systemImage: "location.slash")
                .font(.system(size: 13, weight: .semibold))
            Text("시스템 설정 > 개인정보 보호 및 보안 > 위치 서비스에서 EdgeLauncher 허용.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button("다시 시도") { weather.start() }
                .controlSize(.small)
        }
        .padding(10)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func weatherStat(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 18)
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium, design: .monospaced)).monospacedDigit()
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private func relativeUpdate(_ d: Date) -> String {
        let sec = Int(-d.timeIntervalSinceNow)
        if sec < 60 { return "\(sec)초 전" }
        return "\(sec / 60)분 전"
    }

    // MARK: - Outlook

    private var outlookPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("오늘 일정", systemImage: "calendar")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                if eventVM.hasEventAccess {
                    Text("\(eventVM.events.count)건")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Button(action: { eventVM.reloadEvents() }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }

            if !eventVM.hasEventAccess {
                permissionBanner(message: "캘린더 권한이 필요합니다")
            } else if eventVM.events.isEmpty {
                emptyState("오늘 일정 없음", system: "checkmark.circle")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(eventVM.events, id: \.eventIdentifier) { eventRow($0) }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func eventRow(_ event: EKEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(cgColor: event.calendar?.cgColor ?? CGColor(red: 0.4, green: 0.6, blue: 1, alpha: 1)))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "(제목 없음)").font(.system(size: 16, weight: .semibold)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(timeRange(event)).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                    if let loc = event.location, !loc.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(loc).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                if let cal = event.calendar {
                    Text(cal.title).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Reminders

    private var remindersPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("미리알림", systemImage: "checklist")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                if eventVM.hasReminderAccess {
                    Text("\(eventVM.reminders.count)건")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Button(action: { eventVM.reloadReminders() }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }

            if !eventVM.hasReminderAccess {
                permissionBanner(message: "미리알림 권한이 필요합니다")
            } else if eventVM.reminders.isEmpty {
                emptyState("미리알림 없음", system: "checkmark.seal.fill")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(eventVM.reminders, id: \.calendarItemIdentifier) { reminderRow($0) }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func reminderRow(_ reminder: EKReminder) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: { eventVM.toggleComplete(reminder) }) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(reminder.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title ?? "(제목 없음)")
                    .font(.system(size: 15, weight: .medium))
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                    .lineLimit(1)
                if let due = reminder.dueDateComponents?.date {
                    Text(dueLabel(due))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(isOverdue(due, completed: reminder.isCompleted) ? .red : .secondary)
                }
                if let cal = reminder.calendar {
                    Text(cal.title).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 공통 보조

    private func permissionBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "lock.fill").font(.system(size: 14, weight: .semibold))
            Text("시스템 설정 > 개인정보 보호 및 보안에서 EdgeLauncher 허용.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Button("권한 다시 요청") { Task { await eventVM.requestAccess() } }.controlSize(.small)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func emptyState(_ title: String, system: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: system).font(.system(size: 32)).foregroundStyle(.green)
            Text(title).font(.system(size: 14)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 24)
    }

    private func timeRange(_ event: EKEvent) -> String {
        if event.isAllDay { return "종일" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "\(f.string(from: event.startDate)) – \(f.string(from: event.endDate))"
    }

    private func dueLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR")
        let cal = Calendar.current
        if cal.isDateInToday(date) { f.dateFormat = "HH:mm '오늘'" }
        else if cal.isDateInTomorrow(date) { f.dateFormat = "HH:mm '내일'" }
        else { f.dateFormat = "M월 d일 HH:mm" }
        return f.string(from: date)
    }

    private func isOverdue(_ date: Date, completed: Bool) -> Bool {
        !completed && date < Date()
    }

    private var timeText: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: now)
    }
    private var dateText: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "yyyy년 M월 d일"; return f.string(from: now)
    }
    private var dayText: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "EEEE"; return f.string(from: now)
    }
    private var weekProgress: String {
        let wd = Calendar.current.component(.weekday, from: now)
        let mb = ((wd + 5) % 7) + 1
        return "\(mb)/7"
    }
    private var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0
    }
}
