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
        let reminderCards = reminderBridge.cards
        let hiddenIds = Set(board.hiddenCardIds)
        // 미리알림 컬럼이 있을 때만 reminderBridge 권한 요청 시도.
        if reminderCards.isEmpty,
           board.columns.contains(where: { $0.name.isKanbanReminderColumn }),
           !reminderBridge.hasAccess {
            Task { await reminderBridge.requestAccessIfNeeded() }
        }
        return board.columns.map { col in
            var working = col
            if col.name.isKanbanReminderColumn {
                // 외부 미리알림을 컬럼 상단에 주입. 기존 카드는 그대로 유지.
                working.cards = reminderCards + col.cards
            }
            working.cards = working.cards.filter { card in
                let hiddenAndHiding = !showHiddenCards && hiddenIds.contains(card.id)
                if hiddenAndHiding { return false }
                if !hasSearch && !hasFilter { return true }
                let matchesSearch = !hasSearch
                    || card.title.lowercased().contains(needle)
                    || card.notes.lowercased().contains(needle)
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

    func startNewCard(in columnId: UUID) {
        editingCard = KanbanCard(title: "")
        editingTargetColumnId = columnId
    }

    func editCard(_ card: KanbanCard) {
        // 미리알림 카드는 외부 데이터라 편집 불가. 디테일 패널만 띄움.
        if reminderBridge.isReminderCard(card.id) {
            detailCard = card
            return
        }
        editingCard = card
        editingTargetColumnId = nil
        detailCard = nil
    }

    func saveEditing(_ card: KanbanCard) {
        if let columnId = editingTargetColumnId {
            store.addCard(card, to: columnId)
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

    func handleDrop(providers: [NSItemProvider], toColumn: UUID, toIndex: Int) -> Bool {
        if let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.kanbanCardRef.identifier)
        }) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.kanbanCardRef.identifier) { [weak self] data, _ in
                guard let self,
                      let data,
                      let ref = try? JSONDecoder().decode(KanbanCardRef.self, from: data) else { return }
                Task { @MainActor in
                    _ = self.handleDrop(ref: ref, toColumn: toColumn, toIndex: toIndex)
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
                    _ = self.handleDrop(ref: ref, toColumn: toColumn, toIndex: toIndex)
                }
            }
            return true
        }

        return false
    }

    func handleDrop(ref: KanbanCardRef, toColumn: UUID, toIndex: Int) -> Bool {
        guard let board = activeBoard, ref.boardId == board.id else { return false }
        // 미리알림 카드는 store 에 존재하지 않으므로 이동 불가.
        if reminderBridge.isReminderCard(ref.cardId) { return false }
        store.moveCard(cardId: ref.cardId, fromColumn: ref.sourceColumnId, toColumn: toColumn, toIndex: toIndex)
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
