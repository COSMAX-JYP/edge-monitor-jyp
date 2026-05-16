import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class StreamDeckViewModel {
    @ObservationIgnored
    let store: StreamDeckStore
    @ObservationIgnored
    let permission: PermissionService
    @ObservationIgnored
    let stats: ActionStatsStore

    var isEditing: Bool = false
    var editingPosition: GridPosition?
    var editingButton: StreamDeckButton?
    var executingButtonId: UUID?
    var lastError: String?
    var lastFiredFlashId: UUID?

    var pendingConfirm: StreamDeckButton?
    var lastOutput: ActionOutput?
    var editingPage: StreamDeckPage?
    var pendingDeletePage: StreamDeckPage?
    var isShowingStats: Bool = false

    init(store: StreamDeckStore, permission: PermissionService, stats: ActionStatsStore? = nil) {
        self.store = store
        self.permission = permission
        self.stats = stats ?? ActionStatsStore()
    }

    var activePage: StreamDeckPage? { store.activePage }
    var pages: [StreamDeckPage] { store.data.pages }
    var activePageIndex: Int {
        store.data.pages.firstIndex { $0.id == store.data.activePageId } ?? 0
    }

    func toggleEditing() {
        isEditing.toggle()
        if !isEditing {
            editingPosition = nil
            editingButton = nil
        }
    }

    func beginEditing(at position: GridPosition) {
        editingPosition = position
        if let existing = store.activePage?.button(at: position) {
            editingButton = existing
        } else {
            editingButton = StreamDeckButton(position: position)
        }
    }

    func saveButton(_ button: StreamDeckButton) {
        store.upsertButton(button)
        editingPosition = nil
        editingButton = nil
    }

    func cancelEditing() {
        editingPosition = nil
        editingButton = nil
    }

    func deleteButton(at position: GridPosition) {
        store.deleteButton(at: position)
        editingPosition = nil
        editingButton = nil
    }

    func tap(_ button: StreamDeckButton) {
        if button.action.requiresConfirmation {
            pendingConfirm = button
            return
        }
        execute(button)
    }

    func confirmAndExecute() {
        guard let button = pendingConfirm else { return }
        pendingConfirm = nil
        execute(button)
    }

    func cancelConfirm() {
        pendingConfirm = nil
    }

    private func execute(_ button: StreamDeckButton) {
        executingButtonId = button.id
        lastFiredFlashId = button.id
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        stats.recordTap(button.id)
        let startedAt = Date()
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await ActionExecutor.run(button.action)
                let duration = Date().timeIntervalSince(startedAt)
                self.stats.recordSuccess(button.id, duration: duration)
                self.lastError = nil
                if let output = result.output, !output.isEmpty {
                    self.lastOutput = ActionOutput(label: button.label.isEmpty ? button.action.kindLabel : button.label, text: output)
                }
            } catch let err as ActionExecutorError {
                self.lastError = err.errorDescription
                self.stats.recordError(button.id, message: err.errorDescription ?? "오류")
                switch err {
                case .accessibilityNotAuthorized:
                    _ = try? await self.permission.request(.accessibility)
                case .automationNotAuthorized:
                    _ = try? await self.permission.request(.automation)
                default:
                    break
                }
            } catch {
                self.lastError = error.localizedDescription
                self.stats.recordError(button.id, message: error.localizedDescription)
            }
            self.executingButtonId = nil
            try? await Task.sleep(for: .milliseconds(300))
            if self.lastFiredFlashId == button.id {
                self.lastFiredFlashId = nil
            }
        }
    }

    // MARK: - Stats UI

    func openStats() { isShowingStats = true }
    func closeStats() { isShowingStats = false }
    func resetStats() { stats.reset() }

    func buttonForStats(_ buttonId: UUID) -> StreamDeckButton? {
        for page in store.data.pages {
            if let b = page.buttons.first(where: { $0.id == buttonId }) { return b }
        }
        return nil
    }

    func pageForButton(_ buttonId: UUID) -> StreamDeckPage? {
        store.data.pages.first { $0.buttons.contains { $0.id == buttonId } }
    }

    func clearError() { lastError = nil }
    func dismissOutput() { lastOutput = nil }

    // MARK: - Page navigation

    func selectPage(_ id: UUID) {
        store.setActivePage(id)
        editingPosition = nil
        editingButton = nil
    }

    func selectPage(index: Int) {
        let list = pages
        guard index >= 0, index < list.count else { return }
        selectPage(list[index].id)
    }

    func nextPage() {
        let next = activePageIndex + 1
        guard next < pages.count else { return }
        selectPage(index: next)
    }

    func prevPage() {
        let prev = activePageIndex - 1
        guard prev >= 0 else { return }
        selectPage(index: prev)
    }

    func startCreatePage() {
        let id = store.addPage()
        editingPage = store.data.pages.first { $0.id == id }
    }

    func startRenamePage(_ page: StreamDeckPage) {
        editingPage = page
    }

    func savePageEdit(_ page: StreamDeckPage) {
        store.renamePage(page.id, name: page.name.trimmingCharacters(in: .whitespaces).isEmpty ? "이름 없음" : page.name)
        store.setPageColor(page.id, colorHex: page.colorHex)
        editingPage = nil
    }

    func cancelPageEdit() {
        editingPage = nil
    }

    func requestDeletePage(_ page: StreamDeckPage) {
        guard pages.count > 1 else { return }
        pendingDeletePage = page
    }

    func confirmDeletePage() {
        guard let page = pendingDeletePage else { return }
        store.deletePage(page.id)
        pendingDeletePage = nil
    }

    func cancelDeletePage() {
        pendingDeletePage = nil
    }

    // MARK: - Webhook template

    @discardableResult
    func addButtonFromWebhookTemplate(_ template: WebhookTemplate) -> StreamDeckButton? {
        guard let page = activePage else { return nil }
        guard let slot = firstEmptySlot(in: page) else {
            lastError = "빈 슬롯이 없습니다. 페이지를 추가하거나 버튼을 정리하세요."
            return nil
        }
        let action = StreamDeckAction.webhook(
            url: template.urlPlaceholder,
            method: template.method,
            headers: template.headers,
            body: template.bodyTemplate,
            requireConfirm: true
        )
        let button = StreamDeckButton(
            position: slot,
            label: template.name,
            icon: IconSpec(type: .sfSymbol, value: template.iconSymbol),
            backgroundHex: "#1B3A57",
            foregroundHex: "#FFFFFF",
            action: action
        )
        store.upsertButton(button)
        editingButton = button
        editingPosition = slot
        return button
    }

    private func firstEmptySlot(in page: StreamDeckPage) -> GridPosition? {
        for row in 0..<page.gridSize.rows {
            for col in 0..<page.gridSize.cols {
                let pos = GridPosition(row: row, col: col)
                if page.button(at: pos) == nil { return pos }
            }
        }
        return nil
    }
}

struct ActionOutput: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let text: String
}
