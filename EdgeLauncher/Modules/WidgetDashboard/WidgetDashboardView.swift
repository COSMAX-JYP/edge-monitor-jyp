import Combine
import EventKit
import SwiftUI

struct WidgetDashboardView: View {
    @State private var now = Date()
    @StateObject private var eventVM = EventStoreVM()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            topRow
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
        .task { await eventVM.requestAccess() }
    }

    // MARK: - 상단 시간 + 날짜

    private var topRow: some View {
        HStack(spacing: 36) {
            Text(timeText)
                .font(.system(size: 100, weight: .ultraLight, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(LinearGradient(
                    colors: [Color.primary, Color.primary.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                ))

            VStack(alignment: .leading, spacing: 6) {
                Text(dateText)
                    .font(.system(size: 28, weight: .regular, design: .rounded))
                Text(dayText)
                    .font(.system(size: 20, weight: .light, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Label(weekProgress, systemImage: "calendar.badge.clock")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text("\(dayOfYear)일째 / 365일")
                    .font(.system(size: 11, weight: .light, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.08), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: - 날씨 (축소)

    private var weatherPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("날씨", systemImage: "cloud.sun.fill")
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.multicolor)

            HStack(spacing: 12) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 48))
                    .symbolRenderingMode(.multicolor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("--°")
                        .font(.system(size: 40, weight: .ultraLight))
                        .monospacedDigit()
                    Text("연동 예정")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                weatherStat(icon: "humidity.fill", label: "습도", value: "--%")
                weatherStat(icon: "wind", label: "바람", value: "-- m/s")
                weatherStat(icon: "sun.max.fill", label: "UV 지수", value: "--")
            }

            Spacer()

            Text("WeatherKit 연동 예정")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func weatherStat(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .monospacedDigit()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.background.opacity(0.5))
        .cornerRadius(6)
    }

    // MARK: - Outlook / 캘린더 일정

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
                permissionBanner(message: "캘린더 권한이 필요합니다", system: "calendar")
            } else if eventVM.events.isEmpty {
                emptyState("오늘 일정 없음", system: "checkmark.circle")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(eventVM.events, id: \.eventIdentifier) { event in
                            eventRow(event)
                        }
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
                Text(event.title ?? "(제목 없음)")
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(timeRange(event))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
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
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.background.opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - 미리알림 (Reminders)

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
                permissionBanner(message: "미리알림 권한이 필요합니다", system: "checklist")
            } else if eventVM.reminders.isEmpty {
                emptyState("미리알림 없음", system: "checkmark.seal.fill")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(eventVM.reminders, id: \.calendarItemIdentifier) { reminder in
                            reminderRow(reminder)
                        }
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
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.background.opacity(0.5))
        .cornerRadius(6)
    }

    // MARK: - 공통 보조

    private func permissionBanner(message: String, system: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
            Text("시스템 설정 > 개인정보 보호 및 보안에서 EdgeLauncher 허용.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button("권한 다시 요청") {
                Task { await eventVM.requestAccess() }
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.12))
        .cornerRadius(8)
    }

    private func emptyState(_ title: String, system: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: system)
                .font(.system(size: 32))
                .foregroundStyle(.green)
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    private func timeRange(_ event: EKEvent) -> String {
        if event.isAllDay { return "종일" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: event.startDate)) – \(f.string(from: event.endDate))"
    }

    private func dueLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            f.dateFormat = "HH:mm '오늘'"
        } else if cal.isDateInTomorrow(date) {
            f.dateFormat = "HH:mm '내일'"
        } else {
            f.dateFormat = "M월 d일 HH:mm"
        }
        return f.string(from: date)
    }

    private func isOverdue(_ date: Date, completed: Bool) -> Bool {
        !completed && date < Date()
    }

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: now)
    }
    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일"
        return f.string(from: now)
    }
    private var dayText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "EEEE"
        return f.string(from: now)
    }
    private var weekProgress: String {
        let weekday = Calendar.current.component(.weekday, from: now)
        let mondayBased = ((weekday + 5) % 7) + 1
        return "이번 주 \(mondayBased)/7일"
    }
    private var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0
    }
}
