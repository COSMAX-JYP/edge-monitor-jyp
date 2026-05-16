import Foundation
import Observation

@Observable
@MainActor
final class AtomicJSONStore<T: Codable & Versioned> {
    private(set) var value: T
    private(set) var lastError: Error?

    @ObservationIgnored private let url: URL
    @ObservationIgnored private let rotator: BackupRotator
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let migrate: (Int, Data) throws -> T
    @ObservationIgnored private var pendingSaveTask: Task<Void, Never>?

    init(
        url: URL,
        default defaultValue: T,
        debounce: Duration = .milliseconds(800),
        migrate: @escaping (Int, Data) throws -> T = { version, _ in
            throw SchemaMigrationError.unsupportedVersion(version, supported: T.schemaVersion)
        }
    ) {
        self.url = url
        self.rotator = BackupRotator(url: url)
        self.debounce = debounce
        self.migrate = migrate

        if let loaded = Self.tryLoad(url: url, migrate: migrate) {
            self.value = loaded
        } else if let backup = BackupRotator(url: url).latestBackup(),
                  let loaded = Self.tryLoad(url: backup, migrate: migrate) {
            self.value = loaded
        } else {
            self.value = defaultValue
        }
    }

    deinit {
        pendingSaveTask?.cancel()
    }

    func update(_ block: (inout T) -> Void) {
        block(&value)
        scheduleSave()
    }

    func replace(_ newValue: T) {
        value = newValue
        scheduleSave()
    }

    func scheduleSave() {
        pendingSaveTask?.cancel()
        let snapshot = value
        let url = url
        let rotator = rotator
        let debounce = debounce
        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            if Task.isCancelled { return }
            do {
                try AtomicJSONStore.persist(value: snapshot, url: url, rotator: rotator)
                self?.clearPendingAndError()
            } catch {
                self?.recordError(error)
            }
        }
    }

    func flush() async throws {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        try AtomicJSONStore.persist(value: value, url: url, rotator: rotator)
        lastError = nil
    }

    func reload() throws {
        if let loaded = Self.tryLoad(url: url, migrate: migrate) {
            value = loaded
        } else {
            throw CocoaError(.fileReadUnknown)
        }
    }

    private func clearPendingAndError() {
        pendingSaveTask = nil
        lastError = nil
    }

    private func recordError(_ error: Error) {
        pendingSaveTask = nil
        lastError = error
    }

    private static func tryLoad(url: URL, migrate: (Int, Data) throws -> T) -> T? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(VersionedEnvelope<T>.self, from: data) {
            if envelope.schemaVersion == T.schemaVersion {
                return envelope.payload
            }
            return try? migrate(envelope.schemaVersion, data)
        }
        return try? decoder.decode(T.self, from: data)
    }

    static func persist(value: T, url: URL, rotator: BackupRotator) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let envelope = VersionedEnvelope(payload: value)
        let data = try encoder.encode(envelope)
        try AtomicFileWriter.write(data, to: url)
        try? rotator.rotate()
    }
}
