import Foundation
import Observation

@Observable
@MainActor
final class StreamDeckStore {
    @ObservationIgnored
    private let backing: AtomicJSONStore<StreamDeckData>

    var data: StreamDeckData { backing.value }

    init(url: URL? = nil) {
        let location = url ?? StreamDeckStore.defaultURL()
        self.backing = AtomicJSONStore<StreamDeckData>(
            url: location,
            default: StreamDeckData.makeDefault()
        )
        if backing.value.pages.isEmpty {
            backing.replace(StreamDeckData.makeDefault())
        } else if backing.value.activePageId == nil,
                  let first = backing.value.pages.first {
            backing.update { $0.activePageId = first.id }
        }
        let target = GridSize.default
        backing.update { data in
            for (idx, page) in data.pages.enumerated() where page.gridSize != target {
                data.pages[idx].gridSize = target
                data.pages[idx].buttons = page.buttons.filter { target.contains($0.position) }
            }
        }
    }

    static func defaultURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("EdgeLauncher", isDirectory: true)
            .appendingPathComponent("streamdeck.json")
    }

    func flush() async throws {
        try await backing.flush()
    }

    var activePage: StreamDeckPage? {
        guard let id = data.activePageId else { return data.pages.first }
        return data.pages.first { $0.id == id }
    }

    // MARK: - Button CRUD

    func upsertButton(_ button: StreamDeckButton) {
        mutateActivePage { page in
            if let idx = page.buttons.firstIndex(where: { $0.id == button.id }) {
                var updated = button
                updated.updatedAt = Date()
                page.buttons[idx] = updated
            } else if let idx = page.buttons.firstIndex(where: { $0.position == button.position }) {
                var updated = button
                updated.updatedAt = Date()
                page.buttons[idx] = updated
            } else {
                page.buttons.append(button)
            }
        }
    }

    func deleteButton(at position: GridPosition) {
        mutateActivePage { page in
            page.buttons.removeAll { $0.position == position }
        }
    }

    func deleteButton(id: UUID) {
        mutateActivePage { page in
            page.buttons.removeAll { $0.id == id }
        }
    }

    // MARK: - Page CRUD

    func setActivePage(_ id: UUID) {
        backing.update { $0.activePageId = id }
    }

    @discardableResult
    func addPage(name: String = "새 페이지", colorHex: String = "#4A90E2") -> UUID {
        let page = StreamDeckPage(name: name, colorHex: colorHex)
        backing.update {
            $0.pages.append(page)
            $0.activePageId = page.id
        }
        return page.id
    }

    func renamePage(_ id: UUID, name: String) {
        backing.update { data in
            guard let idx = data.pages.firstIndex(where: { $0.id == id }) else { return }
            data.pages[idx].name = name
            data.pages[idx].updatedAt = Date()
        }
    }

    func setPageColor(_ id: UUID, colorHex: String) {
        backing.update { data in
            guard let idx = data.pages.firstIndex(where: { $0.id == id }) else { return }
            data.pages[idx].colorHex = colorHex
            data.pages[idx].updatedAt = Date()
        }
    }

    func deletePage(_ id: UUID) {
        backing.update { data in
            guard data.pages.count > 1 else { return }
            data.pages.removeAll { $0.id == id }
            if data.activePageId == id {
                data.activePageId = data.pages.first?.id
            }
        }
    }

    func reorderPages(from: Int, to: Int) {
        backing.update { data in
            guard from != to,
                  from >= 0, from < data.pages.count,
                  to >= 0, to <= data.pages.count else { return }
            let item = data.pages.remove(at: from)
            data.pages.insert(item, at: min(to, data.pages.count))
        }
    }

    // MARK: - Helpers

    private func mutateActivePage(_ block: (inout StreamDeckPage) -> Void) {
        backing.update { data in
            guard let activeId = data.activePageId,
                  let idx = data.pages.firstIndex(where: { $0.id == activeId }) else {
                return
            }
            block(&data.pages[idx])
            data.pages[idx].updatedAt = Date()
        }
    }
}
