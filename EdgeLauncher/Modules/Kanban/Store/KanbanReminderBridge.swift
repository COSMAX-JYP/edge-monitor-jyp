import CryptoKit
import EventKit
import Foundation
import Observation

/// macOS 미리알림(Reminders)을 KanbanCard 형태로 변환해 read-only로 공급하는 브릿지.
/// 컬럼 이름에 "+미리알림" 접미사가 붙은 컬럼에 한해 KanbanViewModel.visibleColumns 가 이 카드를 주입한다.
@Observable
@MainActor
final class KanbanReminderBridge {
    private(set) var cards: [KanbanCard] = []
    private(set) var ids: Set<UUID> = []
    private(set) var hasAccess: Bool = false
    @ObservationIgnored private var identifierMap: [UUID: String] = [:]
    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var changeObserver: NSObjectProtocol?
    @ObservationIgnored private var fetchToken: UUID = UUID()

    init() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        hasAccess = Self.isAuthorized(status)
        if hasAccess { reload() } else {
            Task { await requestAccessIfNeeded() }
        }
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    deinit {
        if let observer = changeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func requestAccessIfNeeded() async {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .notDetermined else {
            hasAccess = Self.isAuthorized(status)
            if hasAccess { reload() }
            return
        }
        do {
            if #available(macOS 14, *) {
                hasAccess = try await store.requestFullAccessToReminders()
            } else {
                hasAccess = try await store.requestAccess(to: .reminder)
            }
        } catch {
            hasAccess = false
        }
        if hasAccess { reload() }
    }

    func reload() {
        guard hasAccess else { return }
        let token = UUID()
        fetchToken = token
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { [weak self] fetched in
            Task { @MainActor in
                guard let self, self.fetchToken == token else { return }
                let sorted = (fetched ?? []).sorted { a, b in
                    let da = a.dueDateComponents?.date ?? Date.distantFuture
                    let db = b.dueDateComponents?.date ?? Date.distantFuture
                    if da == db { return (a.title ?? "") < (b.title ?? "") }
                    return da < db
                }
                let limited = Array(sorted.prefix(50))
                var newCards: [KanbanCard] = []
                var newMap: [UUID: String] = [:]
                newCards.reserveCapacity(limited.count)
                for reminder in limited {
                    let card = Self.makeCard(from: reminder)
                    newCards.append(card)
                    newMap[card.id] = reminder.calendarItemIdentifier
                }
                self.cards = newCards
                self.ids = Set(newCards.map(\.id))
                self.identifierMap = newMap
            }
        }
    }

    /// Reminders 앱에서 해당 미리알림을 완료 처리. 실패 시 false.
    @discardableResult
    func markComplete(cardId: UUID) -> Bool {
        guard hasAccess,
              let identifier = identifierMap[cardId],
              let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else {
            return false
        }
        reminder.isCompleted = true
        do {
            try store.save(reminder, commit: true)
            reload()
            return true
        } catch {
            return false
        }
    }

    /// 카드 ID가 이 브릿지에서 공급한 미리알림 카드인지 여부.
    func isReminderCard(_ id: UUID) -> Bool {
        ids.contains(id)
    }

    private static func makeCard(from reminder: EKReminder) -> KanbanCard {
        let title = reminder.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "(제목 없음)"
        let notes = reminder.notes ?? ""
        let due = reminder.dueDateComponents?.date
        return KanbanCard(
            id: Self.deterministicUUID(from: reminder.calendarItemIdentifier),
            title: title,
            notes: notes,
            labelIds: [],
            dueDate: due,
            colorHex: nil,
            assignee: reminder.calendar?.title ?? "",
            createdAt: reminder.creationDate ?? Date(),
            updatedAt: reminder.lastModifiedDate ?? Date()
        )
    }

    private static func deterministicUUID(from string: String) -> UUID {
        let hash = Insecure.MD5.hash(data: Data(string.utf8))
        let bytes = Array(hash)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func isAuthorized(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }
}

extension String {
    /// 컬럼 이름이 미리알림 컬럼인지 검사. "+미리알림" 접미사로 식별.
    var isKanbanReminderColumn: Bool {
        hasSuffix("+미리알림")
    }
}
