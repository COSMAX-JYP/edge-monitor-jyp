import Combine
import EventKit
import Foundation
import AppKit
import os

@MainActor
final class EventStoreVM: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var reminders: [EKReminder] = []
    @Published var hasEventAccess: Bool = false
    @Published var hasReminderAccess: Bool = false
    @Published var errorMessage: String?
    @Published var calendarStatusText: String = ""
    @Published var reminderStatusText: String = ""
    @Published var isRequestingCalendarAccess: Bool = false

    private let store = EKEventStore()

    init() {
        refreshAuthorizationState()
    }

    func refreshAuthorizationState() {
        let eventStatus = EKEventStore.authorizationStatus(for: .event)
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        hasEventAccess = Self.isCalendarAuthorized(eventStatus)
        hasReminderAccess = Self.isReminderAuthorized(reminderStatus)
        calendarStatusText = Self.statusDescription(eventStatus)
        reminderStatusText = Self.statusDescription(reminderStatus)
        if hasEventAccess {
            reloadEvents()
        }
        if hasReminderAccess {
            reloadReminders()
        }
    }

    func requestAccess() async {
        await requestCalendarAccess()
        await requestReminderAccess()
    }

    func requestCalendarAccess() async {
        NSApp.activate(ignoringOtherApps: true)
        await Task.yield()
        let status = EKEventStore.authorizationStatus(for: .event)
        calendarStatusText = Self.statusDescription(status)
        guard status == .notDetermined else {
            hasEventAccess = Self.isCalendarAuthorized(status)
            if hasEventAccess {
                reloadEvents()
            } else {
                openPrivacySettings(anchor: "Privacy_Calendars")
            }
            return
        }

        isRequestingCalendarAccess = true
        defer { isRequestingCalendarAccess = false }

        do {
            hasEventAccess = try await requestCalendarAccessWithCallbacks()
            if !hasEventAccess && EKEventStore.authorizationStatus(for: .event) == .notDetermined {
                hasEventAccess = try await requestLegacyCalendarAccess()
            }
        } catch {
            hasEventAccess = false
            errorMessage = error.localizedDescription
            AppLog.event.error("calendar access: \(error.localizedDescription)")
            ErrorBus.shared.publish("캘린더", error.localizedDescription)
        }
        await refreshCalendarAuthorizationAfterTCCUpdate()
    }

    private func refreshCalendarAuthorizationAfterTCCUpdate() async {
        for attempt in 0..<8 {
            let updatedStatus = EKEventStore.authorizationStatus(for: .event)
            calendarStatusText = Self.statusDescription(updatedStatus)
            hasEventAccess = Self.isCalendarAuthorized(updatedStatus)
            if hasEventAccess {
                errorMessage = nil
                reloadEvents()
                return
            }
            if updatedStatus == .denied || updatedStatus == .restricted {
                openPrivacySettings(anchor: "Privacy_Calendars")
                return
            }
            if attempt < 7 {
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        let updatedStatus = EKEventStore.authorizationStatus(for: .event)
        calendarStatusText = Self.statusDescription(updatedStatus)
        hasEventAccess = Self.isCalendarAuthorized(updatedStatus)
        if hasEventAccess {
            reloadEvents()
        } else if updatedStatus == .denied || updatedStatus == .restricted {
            openPrivacySettings(anchor: "Privacy_Calendars")
        } else {
            errorMessage = "캘린더 권한 요청이 macOS에 등록되지 않았습니다. 다시 요청을 눌러주세요."
        }
    }

    func requestReminderAccess() async {
        NSApp.activate(ignoringOtherApps: true)
        let status = EKEventStore.authorizationStatus(for: .reminder)
        reminderStatusText = Self.statusDescription(status)
        guard status == .notDetermined else {
            hasReminderAccess = Self.isReminderAuthorized(status)
            if hasReminderAccess {
                reloadReminders()
            } else {
                openPrivacySettings(anchor: "Privacy_Reminders")
            }
            return
        }

        do {
            if #available(macOS 14, *) {
                hasReminderAccess = try await store.requestFullAccessToReminders()
            } else {
                hasReminderAccess = try await store.requestAccess(to: .reminder)
            }
        } catch {
            hasReminderAccess = false
        }
        if hasReminderAccess {
            reloadReminders()
        } else if EKEventStore.authorizationStatus(for: .reminder) == .denied || EKEventStore.authorizationStatus(for: .reminder) == .restricted {
            openPrivacySettings(anchor: "Privacy_Reminders")
        }
        reminderStatusText = Self.statusDescription(EKEventStore.authorizationStatus(for: .reminder))
    }

    func reloadEvents() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    func reloadReminders() {
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { [weak self] fetched in
            Task { @MainActor in
                guard let self else { return }
                let list = (fetched ?? []).sorted { a, b in
                    let da = a.dueDateComponents?.date ?? Date.distantFuture
                    let db = b.dueDateComponents?.date ?? Date.distantFuture
                    if da == db { return (a.title ?? "") < (b.title ?? "") }
                    return da < db
                }
                self.reminders = Array(list.prefix(20))
            }
        }
    }

    func toggleComplete(_ reminder: EKReminder) {
        reminder.isCompleted.toggle()
        do {
            try store.save(reminder, commit: true)
            reloadReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openPrivacySettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func requestCalendarAccessWithCallbacks() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            if #available(macOS 14, *) {
                store.requestFullAccessToEvents { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                store.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    private func requestLegacyCalendarAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(to: .event) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private static func isCalendarAuthorized(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    private static func isReminderAuthorized(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    private static func statusDescription(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "권한 미요청"
        case .restricted:
            return "제한됨"
        case .denied:
            return "거부됨"
        case .authorized:
            return "허용됨"
        case .writeOnly:
            return "쓰기 전용"
        case .fullAccess:
            return "전체 접근 허용"
        @unknown default:
            return "알 수 없음"
        }
    }
}
