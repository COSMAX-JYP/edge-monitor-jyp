import Foundation
import Observation
import AppKit
import UniformTypeIdentifiers

@Observable
@MainActor
final class KanbanViewModel {
    @ObservationIgnored
    let store: KanbanStore
    @ObservationIgnored
    let trash: TrashStore
    @ObservationIgnored
    let backup: BackupService
    @ObservationIgnored
    let reminderBridge: KanbanReminderBridge

    var searchQuery: String = ""
    var filterLabelIds: Set<UUID> = []
    var editingCard: KanbanCard?
    var editingTargetColumnId: UUID?
    var detailCard: KanbanCard?
    var pendingDeleteCard: KanbanCard?
    var showHiddenCards: Bool = false

    var editingBoard: KanbanBoard?
    var isCreatingBoard: Bool = false
    var pendingDeleteBoardId: UUID?
    var isManagingLabels: Bool = false

    var lastUndoToast: String?
    var canUndo: Bool { lastTrashedId != nil }

    @ObservationIgnored
    private var lastTrashedId: UUID?
    @ObservationIgnored
    private var toastClearTask: Task<Void, Never>?

    init(
        store: KanbanStore,
        trash: TrashStore? = nil,
        backup: BackupService? = nil,
        reminderBridge: KanbanReminderBridge? = nil
    ) {
        self.store = store
        self.trash = trash ?? TrashStore()
        self.backup = backup ?? BackupService(dataURL: store.dataURL)
        self.reminderBridge = reminderBridge ?? KanbanReminderBridge()
        self.trash.sweep()
        self.backup.snapshotIfNeeded()
        self.backup.sweep()
    }

    var activeBoard: KanbanBoard? { store.activeBoard }
    var boards: [KanbanBoard] { store.data.boards }

    var visibleColumns: [KanbanColumn] {
        guard let board = activeBoard else { return [] }
        let needle = searchQuery.lowercased()
        let hasSearch = !searchQuery.isEmpty
        let hasFilter = !filterLabelIds.isEmpty
        let hiddenIds = Set(board.hiddenCardIds)
        return board.columns.map { col in
            var working = col
            if reminderBridge.listNames.contains(col.name) {
                // 미리알림 전용 컬럼: 컬럼명과 동일한 리스트의 미리알림만 표시.
                // 로컬 카드는 표시하지 않는다 (전용 강제).
                working.cards = reminderBridge.cardsByList[col.name] ?? []
            }
            working.cards = working.cards.filter { card in
                let hiddenAndHiding = !showHiddenCards && hiddenIds.contains(card.id)
                if hiddenAndHiding { return false }
                if !hasSearch && !hasFilter { return true }
                let matchesSearch = !hasSearch
                    || card.title.lowercased().contains(needle)
                    || card.notes.plainTextFromHTML.lowercased().contains(needle)
                let matchesFilter = !hasFilter
                    || !Set(card.labelIds).isDisjoint(with: filterLabelIds)
                return matchesSearch && matchesFilter
            }
            return working
        }
    }

    func isReminderCard(_ cardId: UUID) -> Bool {
        reminderBridge.isReminderCard(cardId)
    }

    /// 컬럼 이름이 macOS 미리알림 리스트 이름과 일치하면 그 컬럼은 미리알림 전용.
    func isReminderColumn(_ name: String) -> Bool {
        reminderBridge.listNames.contains(name)
    }

    /// 컬럼 id 로 미리알림 전용 여부 판정.
    func isReminderColumn(id columnId: UUID) -> Bool {
        guard let board = activeBoard,
              let col = board.columns.first(where: { $0.id == columnId }) else { return false }
        return reminderBridge.listNames.contains(col.name)
    }

    func isHiddenCard(_ cardId: UUID) -> Bool {
        activeBoard?.hiddenCardIds.contains(cardId) ?? false
    }

    func hideCard(_ card: KanbanCard) {
        store.hideCard(card.id)
        if detailCard?.id == card.id { detailCard = nil }
    }

    func unhideCard(_ card: KanbanCard) {
        store.unhideCard(card.id)
    }

    func toggleShowHidden() {
        showHiddenCards.toggle()
    }

    var hiddenCardCount: Int {
        activeBoard?.hiddenCardIds.count ?? 0
    }

    // MARK: - Card lifecycle

    func startNewCard(in columnId: UUID, isUpper: Bool = false) {
        editingCard = KanbanCard(title: "", isUpper: isUpper)
        editingTargetColumnId = columnId
    }

    /// 카드를 위 30% / 아래 70% 영역 사이에서 토글. SlidePad/메인 윈도우 공통.
    func toggleCardZone(_ cardId: UUID) {
        guard let (boardId, columnId) = store.findColumnId(forCard: cardId) else { return }
        if let board = store.data.boards.first(where: { $0.id == boardId }),
           let column = board.columns.first(where: { $0.id == columnId }),
           let card = column.cards.first(where: { $0.id == cardId }) {
            var updated = card
            updated.isUpper.toggle()
            store.updateCard(updated)
        }
    }

    func editCard(_ card: KanbanCard) {
        // 미리알림 카드도 편집 가능 (수정 시 macOS 미리알림에 반영).
        editingCard = card
        editingTargetColumnId = nil
        detailCard = nil
    }

    func saveEditing(_ card: KanbanCard) {
        if let columnId = editingTargetColumnId {
            // 새 카드. 대상 컬럼이 미리알림 전용이면 macOS 미리알림 생성.
            if isReminderColumn(id: columnId),
               let board = activeBoard,
               let col = board.columns.first(where: { $0.id == columnId }) {
                _ = reminderBridge.createReminder(
                    in: col.name,
                    title: card.title,
                    notes: card.notes,
                    dueDate: card.dueDate
                )
            } else {
                store.addCard(card, to: columnId)
            }
        } else if reminderBridge.isReminderCard(card.id) {
            // 기존 미리알림 카드 수정 → macOS 미리알림 업데이트.
            _ = reminderBridge.updateReminder(
                cardId: card.id,
                title: card.title,
                notes: card.notes,
                dueDate: card.dueDate
            )
        } else {
            store.updateCard(card)
        }
        editingCard = nil
        editingTargetColumnId = nil
    }

    func cancelEditing() {
        editingCard = nil
        editingTargetColumnId = nil
    }

    func showDetail(_ card: KanbanCard) {
        detailCard = card
    }

    func dismissDetail() {
        detailCard = nil
    }

    func requestDelete(_ card: KanbanCard) {
        // 미리알림 카드는 칸반에서 직접 삭제 불가 → Reminders 에서 완료 처리.
        if reminderBridge.isReminderCard(card.id) {
            _ = reminderBridge.markComplete(cardId: card.id)
            if detailCard?.id == card.id { detailCard = nil }
            showToast("미리알림 완료 처리됨")
            return
        }
        pendingDeleteCard = card
    }

    func confirmDelete() {
        guard let card = pendingDeleteCard else { return }
        if let pos = store.findColumnId(forCard: card.id) {
            trash.push(card: card, boardId: pos.boardId, columnId: pos.columnId)
            lastTrashedId = card.id
            showToast("\(card.title.isEmpty ? "(제목 없음)" : card.title) 삭제됨 — Cmd+Z 실행 취소")
        }
        store.deleteCard(card.id)
        if detailCard?.id == card.id { detailCard = nil }
        pendingDeleteCard = nil
    }

    func cancelDelete() {
        pendingDeleteCard = nil
    }

    func undoLastDelete() {
        guard let id = lastTrashedId, let entry = trash.pop(id: id) else { return }
        store.addCard(entry.card, to: entry.columnId)
        lastTrashedId = nil
        showToast("복원됨")
    }

    // MARK: - Checklist mutations

    func toggleChecklistItem(_ itemId: UUID, in cardId: UUID) {
        guard var card = findCard(cardId) else { return }
        guard let idx = card.checklist.firstIndex(where: { $0.id == itemId }) else { return }
        card.checklist[idx].done.toggle()
        card.updatedAt = Date()
        store.updateCard(card)
        if detailCard?.id == cardId { detailCard = card }
    }

    func addChecklistItem(text: String, in cardId: UUID) {
        guard var card = findCard(cardId) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        card.checklist.append(ChecklistItem(text: trimmed, done: false))
        card.updatedAt = Date()
        store.updateCard(card)
        if detailCard?.id == cardId { detailCard = card }
    }

    func removeChecklistItem(_ itemId: UUID, in cardId: UUID) {
        guard var card = findCard(cardId) else { return }
        card.checklist.removeAll { $0.id == itemId }
        card.updatedAt = Date()
        store.updateCard(card)
        if detailCard?.id == cardId { detailCard = card }
    }

    // MARK: - Attachment

    func addAttachments(paths: [String], to cardId: UUID) {
        guard var card = findCard(cardId), !paths.isEmpty else { return }
        for path in paths where !card.attachments.contains(where: { $0.path == path }) {
            card.attachments.append(Attachment(path: path))
        }
        card.updatedAt = Date()
        store.updateCard(card)
        if detailCard?.id == cardId { detailCard = card }
    }

    func removeAttachment(_ attachmentId: UUID, from cardId: UUID) {
        guard var card = findCard(cardId) else { return }
        card.attachments.removeAll { $0.id == attachmentId }
        card.updatedAt = Date()
        store.updateCard(card)
        if detailCard?.id == cardId { detailCard = card }
    }

    func revealAttachment(_ attachment: Attachment) {
        guard attachment.exists else { return }
        NSWorkspace.shared.activateFileViewerSelecting([attachment.fileURL])
    }

    // MARK: - Drag and drop

    func dragProvider(ref: KanbanCardRef) -> NSItemProvider {
        let provider = NSItemProvider()
        guard let data = try? JSONEncoder().encode(ref) else { return provider }
        let textPayload = KanbanDragPayload.textPrefix + data.base64EncodedString()

        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.kanbanCardRef.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(data, nil)
            return nil
        }
        provider.registerObject(textPayload as NSString, visibility: .ownProcess)
        return provider
    }

    func handleDrop(providers: [NSItemProvider], toColumn: UUID, toIndex: Int, toUpper: Bool? = nil) -> Bool {
        if let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.kanbanCardRef.identifier)
        }) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.kanbanCardRef.identifier) { [weak self] data, _ in
                guard let self,
                      let data,
                      let ref = try? JSONDecoder().decode(KanbanCardRef.self, from: data) else { return }
                Task { @MainActor in
                    _ = self.handleDrop(ref: ref, toColumn: toColumn, toIndex: toIndex, toUpper: toUpper)
                }
            }
            return true
        }

        if let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) {
            provider.loadObject(ofClass: NSString.self) { [weak self] item, _ in
                guard let self,
                      let string = item as? String,
                      let ref = KanbanDragPayload.decodeText(string) else { return }
                Task { @MainActor in
                    _ = self.handleDrop(ref: ref, toColumn: toColumn, toIndex: toIndex, toUpper: toUpper)
                }
            }
            return true
        }

        return false
    }

    func handleDrop(ref: KanbanCardRef, toColumn: UUID, toIndex: Int, toUpper: Bool? = nil) -> Bool {
        guard let board = activeBoard, ref.boardId == board.id else { return false }
        guard let targetCol = board.columns.first(where: { $0.id == toColumn }) else { return false }
        let targetIsReminder = reminderBridge.listNames.contains(targetCol.name)
        let sourceIsReminder = reminderBridge.isReminderCard(ref.cardId)

        // 미리알림 카드를 드래그하는 경우.
        if sourceIsReminder {
            if targetIsReminder {
                // 전용 → 전용. 같은 리스트 내 순서 변경은 의미 없고, 다른 리스트로의
                // 이동은 미지원(무시). 드롭 자체는 소비.
                return true
            }
            // 미리알림 → 일반 컬럼: 미리알림 완료 처리 후 로컬 카드로 변환.
            guard let card = reminderBridge.cards.first(where: { $0.id == ref.cardId }) else { return false }
            let local = KanbanCard(
                title: card.title,
                notes: card.notes,
                dueDate: card.dueDate,
                isUpper: toUpper ?? false
            )
            reminderBridge.markComplete(cardId: ref.cardId)
            store.addCard(local, to: toColumn)
            return true
        }

        // 일반 카드를 드래그하는 경우.
        if targetIsReminder {
            // 일반 → 미리알림 전용 컬럼: 미리알림 생성 후 로컬 카드 삭제 (변환).
            guard let sourceCard = findCard(ref.cardId) else { return false }
            let ok = reminderBridge.createReminder(
                in: targetCol.name,
                title: sourceCard.title,
                notes: sourceCard.notes,
                dueDate: sourceCard.dueDate
            )
            if ok { store.deleteCard(ref.cardId) }
            return ok
        }

        // 일반 → 일반: 기존 이동.
        store.moveCard(cardId: ref.cardId, fromColumn: ref.sourceColumnId, toColumn: toColumn, toIndex: toIndex)
        // zone(상/하) 변경 요청이 있으면 같이 적용.
        if let toUpper {
            if let (_, columnId) = store.findColumnId(forCard: ref.cardId),
               let board = store.data.boards.first(where: { $0.id == ref.boardId }),
               let column = board.columns.first(where: { $0.id == columnId }),
               let card = column.cards.first(where: { $0.id == ref.cardId }),
               card.isUpper != toUpper {
                var updated = card
                updated.isUpper = toUpper
                store.updateCard(updated)
            }
        }
        return true
    }

    // MARK: - Board

    func selectBoard(_ id: UUID) {
        store.setActiveBoard(id)
        searchQuery = ""
        filterLabelIds.removeAll()
        detailCard = nil
    }

    func startCreateBoard() {
        editingBoard = KanbanBoard(name: "새 보드")
        isCreatingBoard = true
    }

    func startEditBoard(_ board: KanbanBoard) {
        editingBoard = board
        isCreatingBoard = false
    }

    func cancelBoardEditing() {
        editingBoard = nil
        isCreatingBoard = false
    }

    func saveBoardEditing(_ board: KanbanBoard) {
        if isCreatingBoard {
            store.addBoard(board)
        } else {
            store.renameBoard(board.id, name: board.name)
        }
        editingBoard = nil
        isCreatingBoard = false
    }

    func requestDeleteBoard(_ id: UUID) {
        pendingDeleteBoardId = id
    }

    func confirmDeleteBoard() {
        guard let id = pendingDeleteBoardId else { return }
        store.deleteBoard(id)
        pendingDeleteBoardId = nil
    }

    func cancelDeleteBoard() { pendingDeleteBoardId = nil }

    // MARK: - Columns

    func addColumn(name: String) {
        store.addColumn(KanbanColumn(name: name))
    }

    func renameColumn(_ id: UUID, name: String) {
        store.renameColumn(id, name: name)
    }

    func deleteColumn(_ id: UUID) {
        store.deleteColumn(id)
    }

    // MARK: - Labels

    func openLabelManager() { isManagingLabels = true }
    func closeLabelManager() { isManagingLabels = false }

    func addLabel(name: String, colorHex: String) {
        store.addLabel(KanbanLabel(name: name, colorHex: colorHex))
    }

    func updateLabel(_ label: KanbanLabel) {
        store.updateLabel(label)
    }

    func deleteLabel(_ id: UUID) {
        store.deleteLabel(id)
        filterLabelIds.remove(id)
    }

    // MARK: - Filter / search

    func toggleFilterLabel(_ id: UUID) {
        if filterLabelIds.contains(id) {
            filterLabelIds.remove(id)
        } else {
            filterLabelIds.insert(id)
        }
    }

    func clearFilters() { filterLabelIds.removeAll() }
    func clearSearch() { searchQuery = "" }

    // MARK: - Helpers

    private func findCard(_ id: UUID) -> KanbanCard? {
        guard let board = activeBoard else { return nil }
        for col in board.columns {
            if let c = col.cards.first(where: { $0.id == id }) { return c }
        }
        return nil
    }

    private func showToast(_ message: String) {
        lastUndoToast = message
        toastClearTask?.cancel()
        toastClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            if Task.isCancelled { return }
            self?.lastUndoToast = nil
        }
    }
}

private enum KanbanDragPayload {
    static let textPrefix = "edgelauncher-kanban-card:"

    static func decodeText(_ string: String) -> KanbanCardRef? {
        guard string.hasPrefix(textPrefix) else { return nil }
        let encoded = String(string.dropFirst(textPrefix.count))
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return try? JSONDecoder().decode(KanbanCardRef.self, from: data)
    }
}
