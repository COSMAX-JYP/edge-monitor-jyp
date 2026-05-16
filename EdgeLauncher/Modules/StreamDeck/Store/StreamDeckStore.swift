import Foundation
import Observation

@Observable
@MainActor
final class StreamDeckStore {
    @ObservationIgnored
    private let backing: AtomicJSONStore<StreamDeckData>

    var data: StreamDeckData { backing.value }

    init(url: URL? = nil, seedDefaultApps: Bool = true) {
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
        if seedDefaultApps {
            seedMissingDefaultApps()
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

    func moveButton(id: UUID, to destination: GridPosition) {
        mutateActivePage { page in
            guard page.gridSize.contains(destination),
                  let sourceIndex = page.buttons.firstIndex(where: { $0.id == id }) else {
                return
            }

            let source = page.buttons[sourceIndex].position
            guard source != destination else { return }

            if let destinationIndex = page.buttons.firstIndex(where: { $0.position == destination }) {
                page.buttons[destinationIndex].position = source
                page.buttons[destinationIndex].updatedAt = Date()
            }

            page.buttons[sourceIndex].position = destination
            page.buttons[sourceIndex].updatedAt = Date()
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

    private func seedMissingDefaultApps() {
        backing.update { data in
            guard let pageIndex = data.pages.firstIndex(where: { $0.name == "기본" }) ?? data.pages.indices.first else {
                return
            }

            let allButtons = data.pages.flatMap(\.buttons)
            let existingBundleIds = Set(
                allButtons.compactMap { button -> String? in
                    if case .launchApp(let bundleId) = button.action {
                        return bundleId
                    }
                    return nil
                }
            )
            let existingURLs = Set(
                allButtons.compactMap { button -> String? in
                    if case .openURL(let url) = button.action {
                        return url
                    }
                    return nil
                }
            )
            var occupied = Set(data.pages[pageIndex].buttons.map(\.position))
            var changed = false

            for preset in StreamDeckDefaultAppPreset.all where !existingBundleIds.contains(preset.bundleId) {
                guard let position = Self.firstEmptyPosition(in: data.pages[pageIndex].gridSize, occupied: occupied) else {
                    break
                }
                occupied.insert(position)
                data.pages[pageIndex].buttons.append(preset.makeButton(position: position))
                changed = true
            }

            for preset in StreamDeckDefaultLinkPreset.all where !existingURLs.contains(preset.url) {
                guard let position = Self.firstEmptyPosition(in: data.pages[pageIndex].gridSize, occupied: occupied) else {
                    break
                }
                occupied.insert(position)
                data.pages[pageIndex].buttons.append(preset.makeButton(position: position))
                changed = true
            }

            if changed {
                data.pages[pageIndex].updatedAt = Date()
            }
        }
    }

    private static func firstEmptyPosition(in gridSize: GridSize, occupied: Set<GridPosition>) -> GridPosition? {
        for row in 0..<gridSize.rows {
            for col in 0..<gridSize.cols {
                let position = GridPosition(row: row, col: col)
                if !occupied.contains(position) {
                    return position
                }
            }
        }
        return nil
    }
}

private struct StreamDeckDefaultAppPreset {
    let label: String
    let bundleId: String
    let symbol: String
    let backgroundHex: String
    let foregroundHex: String

    func makeButton(position: GridPosition) -> StreamDeckButton {
        StreamDeckButton(
            position: position,
            label: label,
            icon: IconSpec(type: .sfSymbol, value: symbol),
            backgroundHex: backgroundHex,
            foregroundHex: foregroundHex,
            action: .launchApp(bundleId: bundleId)
        )
    }

    static let all: [StreamDeckDefaultAppPreset] = [
        .init(label: "Warp", bundleId: "dev.warp.Warp-Stable", symbol: "terminal.fill", backgroundHex: "#101827", foregroundHex: "#7DF9C1"),
        .init(label: "Teams", bundleId: "com.microsoft.teams2", symbol: "person.2.fill", backgroundHex: "#4F46E5", foregroundHex: "#FFFFFF"),
        .init(label: "Outlook", bundleId: "com.microsoft.Outlook", symbol: "envelope.fill", backgroundHex: "#0A64D8", foregroundHex: "#FFFFFF"),
        .init(label: "Obsidian", bundleId: "md.obsidian", symbol: "diamond.fill", backgroundHex: "#3F2E7E", foregroundHex: "#E7DDFF"),
        .init(label: "DBeaver", bundleId: "org.jkiss.dbeaver.core.product", symbol: "cylinder.split.1x2.fill", backgroundHex: "#4B3428", foregroundHex: "#FFD9A8"),
        .init(label: "CotEditor", bundleId: "com.coteditor.CotEditor", symbol: "pencil.and.scribble", backgroundHex: "#F5F7FA", foregroundHex: "#27364A"),
        .init(label: "GPT", bundleId: "com.openai.chat", symbol: "sparkles", backgroundHex: "#111827", foregroundHex: "#FFFFFF"),
        .init(label: "Claude", bundleId: "com.anthropic.claudefordesktop", symbol: "sun.max.fill", backgroundHex: "#D97757", foregroundHex: "#FFFFFF"),
        .init(label: "메모", bundleId: "com.apple.Notes", symbol: "note.text", backgroundHex: "#F7D84A", foregroundHex: "#222222"),
        .init(label: "설정", bundleId: "com.apple.systempreferences", symbol: "gearshape.fill", backgroundHex: "#8E8E93", foregroundHex: "#FFFFFF"),
        .init(label: "Chrome", bundleId: "com.google.Chrome", symbol: "globe", backgroundHex: "#FFFFFF", foregroundHex: "#1F2937"),
        .init(label: "카카오톡", bundleId: "com.kakao.KakaoTalkMac", symbol: "message.fill", backgroundHex: "#FEE500", foregroundHex: "#371D1E"),
        .init(label: "Excel", bundleId: "com.microsoft.Excel", symbol: "tablecells.fill", backgroundHex: "#107C41", foregroundHex: "#FFFFFF"),
        .init(label: "KMS", bundleId: "com.cosmax.kmsjyp", symbol: "building.2.fill", backgroundHex: "#EEF2FF", foregroundHex: "#243B82"),
        .init(label: "LOG-JYP", bundleId: "com.cosmax.service-log", symbol: "doc.text.fill", backgroundHex: "#FFFFFF", foregroundHex: "#334155")
    ]
}

private struct StreamDeckDefaultLinkPreset {
    let label: String
    let url: String
    let symbol: String
    let backgroundHex: String
    let foregroundHex: String

    func makeButton(position: GridPosition) -> StreamDeckButton {
        StreamDeckButton(
            position: position,
            label: label,
            icon: IconSpec(type: .sfSymbol, value: symbol),
            backgroundHex: backgroundHex,
            foregroundHex: foregroundHex,
            action: .openURL(url: url)
        )
    }

    static let all: [StreamDeckDefaultLinkPreset] = [
        .init(
            label: "PI혁신부문",
            url: "https://cosmaxdt.sharepoint.com/sites/PI_Division/Shared%20Documents/Forms/AllItems.aspx",
            symbol: "folder.fill",
            backgroundHex: "#0F6CBD",
            foregroundHex: "#FFFFFF"
        ),
        .init(
            label: "EAI_Datahub",
            url: "https://cosmaxdt.sharepoint.com/sites/EAI_DataHub/Shared%20Documents/Forms/AllItems.aspx",
            symbol: "externaldrive.connected.to.line.below.fill",
            backgroundHex: "#0E7490",
            foregroundHex: "#FFFFFF"
        ),
        .init(
            label: "비상연락망",
            url: "https://cosmaxdt.sharepoint.com/:x:/s/PI_Division/IQATGEfNEkooSaD8bsxE8mvhAXIcCaipY5uGiwTk2kdnnX4?e=yKsJrJ",
            symbol: "phone.connection.fill",
            backgroundHex: "#B91C1C",
            foregroundHex: "#FFFFFF"
        ),
        .init(
            label: "연차현황",
            url: "https://outlook.cloud.microsoft/calendar/view/month",
            symbol: "calendar.badge.clock",
            backgroundHex: "#2563EB",
            foregroundHex: "#FFFFFF"
        )
    ]
}
