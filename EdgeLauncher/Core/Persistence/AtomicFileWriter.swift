import Foundation

enum AtomicFileWriter {
    static func write(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let temp = directory.appendingPathComponent(".\(url.lastPathComponent).tmp.\(UUID().uuidString)")
        try data.write(to: temp, options: .atomic)

        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw error
        }
    }
}
