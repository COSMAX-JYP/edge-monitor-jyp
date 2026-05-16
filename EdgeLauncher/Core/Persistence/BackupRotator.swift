import Foundation

struct BackupRotator {
    let url: URL
    var maxBackups: Int = 3

    func rotate() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }

        for index in stride(from: maxBackups - 1, through: 1, by: -1) {
            let from = backupURL(index: index)
            let to = backupURL(index: index + 1)
            if fm.fileExists(atPath: from.path) {
                if fm.fileExists(atPath: to.path) {
                    try fm.removeItem(at: to)
                }
                try fm.moveItem(at: from, to: to)
            }
        }

        let firstBackup = backupURL(index: 1)
        if fm.fileExists(atPath: firstBackup.path) {
            try fm.removeItem(at: firstBackup)
        }
        try fm.copyItem(at: url, to: firstBackup)

        let toDelete = backupURL(index: maxBackups + 1)
        if fm.fileExists(atPath: toDelete.path) {
            try? fm.removeItem(at: toDelete)
        }
    }

    func latestBackup() -> URL? {
        for index in 1...maxBackups {
            let candidate = backupURL(index: index)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    func backupURL(index: Int) -> URL {
        url.deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).bak.\(index)")
    }
}
