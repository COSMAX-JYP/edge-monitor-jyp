import CryptoKit
import EventKit
import Foundation
import Observation

/// macOS 미리알림(Reminders)을 KanbanCard 형태로 변환해 공급하는 양방향 브릿지.
/// 칸반 컬럼 이름이 미리알림 리스트(EKCalendar) 이름과 정확히 일치하면, 그 컬럼은
/// 해당 리스트 전용이 되어 KanbanViewModel.visibleColumns 가 그 리스트의 카드를 주입한다.
/// 읽기 + 생성 + 수정 + 완료(=삭제 대체) 를 지원한다.
@Observable
@MainActor
final class KanbanReminderBridge {
    /// 모든 미리알림 리스트의 미완료 카드 합본 (호환용).
    private(set) var cards: [KanbanCard] = []
    /// 리스트(EKCalendar) 이름 → 그 리스트의 미완료 카드들.
    private(set) var cardsByList: [String: [KanbanCard]] = [:]
    /// 사용 가능한 미리알림 리스트 이름들. 전용 컬럼 판정에 사용.
    private(set) var listNames: Set<String> = []
    private(set) var ids: Set<UUID> = []
    private(set) var hasAccess: Bool = false
    /// cardId → EKReminder.calendarItemIdentifier
    @ObservationIgnored private var identifierMap: [UUID: String] = [:]
    /// cardId → 소속 리스트(EKCalendar) 이름
    @ObservationIgnored private var listNameMap: [UUID: String] = [:]
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
        // 권한이 있으면 사용 가능한 리스트 이름은 즉시 채운다 (전용 컬럼 판정용).
        listNames = Set(store.calendars(for: .reminder).map(\.title))
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
                var newCards: [KanbanCard] = []
                var byList: [String: [KanbanCard]] = [:]
                var idMap: [UUID: String] = [:]
                var listMap: [UUID: String] = [:]
                newCards.reserveCapacity(sorted.count)
                for reminder in sorted {
                    let listName = reminder.calendar?.title ?? ""
                    let card = Self.makeCard(from: reminder)
                    newCards.append(card)
                    byList[listName, default: []].append(card)
                    idMap[card.id] = reminder.calendarItemIdentifier
                    listMap[card.id] = listName
                }
                self.cards = newCards
                self.cardsByList = byList
                self.ids = Set(newCards.map(\.id))
                self.identifierMap = idMap
                self.listNameMap = listMap
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

    /// 지정한 리스트(EKCalendar 이름)에 새 미리알림 생성. 실패 시 false.
    @discardableResult
    func createReminder(in listName: String, title: String, notes: String, dueDate: Date?) -> Bool {
        guard hasAccess,
              let calendar = store.calendars(for: .reminder).first(where: { $0.title == listName }) else {
            return false
        }
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar
        reminder.title = title
        reminder.notes = notes.isEmpty ? nil : notes
        reminder.dueDateComponents = Self.dueComponents(from: dueDate)
        do {
            try store.save(reminder, commit: true)
            reload()
            return true
        } catch {
            return false
        }
    }

    /// 기존 미리알림의 제목/노트/마감일 수정. 실패 시 false.
    @discardableResult
    func updateReminder(cardId: UUID, title: String, notes: String, dueDate: Date?) -> Bool {
        guard hasAccess,
              let identifier = identifierMap[cardId],
              let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else {
            return false
        }
        reminder.title = title
        reminder.notes = notes.isEmpty ? nil : notes
        reminder.dueDateComponents = Self.dueComponents(from: dueDate)
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

    /// 카드가 속한 미리알림 리스트(EKCalendar) 이름. 미리알림 카드가 아니면 nil.
    func listName(forCardId id: UUID) -> String? {
        listNameMap[id]
    }

    private static func dueComponents(from date: Date?) -> DateComponents? {
        guard let date else { return nil }
        return Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
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
            assignee: "",
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

