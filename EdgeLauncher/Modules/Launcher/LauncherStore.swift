import AppKit
import Combine
import Foundation

struct LauncherEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var bundleURL: String

    init(id: UUID = UUID(), name: String, bundleURL: String) {
        self.id = id
        self.name = name
        self.bundleURL = bundleURL
    }
}

@MainActor
final class LauncherStore: ObservableObject {
    @Published var entries: [LauncherEntry] = []

    private let key = "module.launcher.entries"

    init() {
        load()
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([LauncherEntry].self, from: data),
           !decoded.isEmpty {
            entries = decoded
            return
        }
        entries = Self.defaultEntries()
        save()
    }

    func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        guard !entries.contains(where: { $0.bundleURL == url.path }) else { return }
        entries.append(LauncherEntry(name: name, bundleURL: url.path))
        save()
    }

    func remove(_ entry: LauncherEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func launch(_ entry: LauncherEntry) {
        let url = URL(fileURLWithPath: entry.bundleURL)
        guard FileManager.default.fileExists(atPath: entry.bundleURL) else {
            NSSound.beep()
            return
        }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, _ in }
    }

    private static func defaultEntries() -> [LauncherEntry] {
        let candidates = [
            "/Applications/Safari.app",
            "/System/Applications/Mail.app",
            "/System/Applications/Notes.app",
            "/System/Applications/Calendar.app",
            "/System/Applications/Reminders.app",
            "/System/Applications/Music.app",
            "/System/Applications/Photos.app",
            "/System/Applications/Maps.app",
            "/System/Applications/Utilities/Terminal.app",
            "/Applications/Xcode.app",
        ]
        return candidates
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { path in
                let url = URL(fileURLWithPath: path)
                return LauncherEntry(name: url.deletingPathExtension().lastPathComponent, bundleURL: path)
            }
    }
}
