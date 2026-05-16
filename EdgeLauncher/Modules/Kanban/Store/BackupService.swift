import Foundation

@MainActor
final class BackupService {
    private let dataURL: URL
    private let snapshotDirectory: URL
    private let retentionDays: Int

    init(dataURL: URL, snapshotDirectory: URL? = nil, retentionDays: Int = 30) {
        self.dataURL = dataURL
        let dir = snapshotDirectory ?? dataURL.deletingLastPathComponent().appendingPathComponent(".snapshots", isDirectory: true)
        self.snapshotDirectory = dir
        self.retentionDays = retentionDays
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    @discardableResult
    func snapshotIfNeeded(referenceDate: Date = Date()) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let stamp = formatter.string(from: referenceDate)
        let target = snapshotDirectory.appendingPathComponent("\(stamp).json")
        if FileManager.default.fileExists(atPath: target.path) {
            return nil
        }
        guard let data = try? Data(contentsOf: dataURL) else { return nil }
        try? data.write(to: target, options: .atomic)
        return target
    }

    func sweep(referenceDate: Date = Date()) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: snapshotDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for url in items where url.pathExtension == "json" {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let mod = values?.contentModificationDate ?? Date.distantPast
            let ageDays = referenceDate.timeIntervalSince(mod) / 86400
            if ageDays >= Double(retentionDays) {
                try? fm.removeItem(at: url)
            }
        }
    }

    func list() -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: snapshotDirectory, includingPropertiesForKeys: nil) else { return [] }
        return items.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}
