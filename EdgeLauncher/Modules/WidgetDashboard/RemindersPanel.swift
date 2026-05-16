import EventKit
import SwiftUI

struct RemindersPanel: View {
    @ObservedObject var eventVM: EventStoreVM

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !eventVM.hasReminderAccess {
                permissionBanner
            } else if eventVM.reminders.isEmpty {
                emptyState
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

    private var header: some View {
        HStack {
            Label("미리알림", systemImage: "checklist").font(.appTitle)
            Spacer()
            if eventVM.hasReminderAccess {
                Text("\(eventVM.reminders.count)건").font(.appCalloutMono).foregroundStyle(.secondary)
            }
            Button(action: { eventVM.reloadReminders() }) {
                Image(systemName: "arrow.clockwise").font(.appCallout)
            }
            .buttonStyle(.plain)
        }
    }

    private func reminderRow(_ reminder: EKReminder) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: { eventVM.toggleComplete(reminder) }) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.appCallout)
                    .foregroundStyle(reminder.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title ?? "(제목 없음)")
                    .font(.appBodyBold)
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                    .lineLimit(1)
                if let due = reminder.dueDateComponents?.date {
                    Text(dueLabel(due))
                        .font(.appCalloutMono)
                        .foregroundStyle(isOverdue(due, completed: reminder.isCompleted) ? .red : .secondary)
                }
                if let cal = reminder.calendar {
                    Text(cal.title).font(.appFootnote).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("미리알림 권한이 필요합니다", systemImage: "lock.fill").font(.appBodyBold)
            Text("시스템 설정 > 개인정보 보호 및 보안에서 EdgeLauncher 허용.")
                .font(.appCallout).foregroundStyle(.secondary)
            Button("권한 다시 요청") { Task { await eventVM.requestReminderAccess() } }.font(.appCallout)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 26)).foregroundStyle(.green)
            Text("미리알림 없음").font(.appCallout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 24)
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
}
