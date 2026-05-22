import AppKit
import Foundation
import Observation

/// 단일 JSON 파일에 대한 atomic 저장소.
/// - debounce 후 임시 파일 → rename 으로 원자적 쓰기
/// - 저장 직후 re-read + decode 검증으로 손상된 쓰기 차단
/// - 백업 회전(default 3) + 메인 파일 손상 시 백업으로 자동 폴백
/// - 앱 비활성/종료 시 자동 synchronous flush
@Observable
@MainActor
final class AtomicJSONStore<T: Codable & Versioned> {
    private(set) var value: T
    private(set) var lastError: Error?

    @ObservationIgnored private let url: URL
    @ObservationIgnored private let rotator: BackupRotator
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let migrate: (Int, Data) throws -> T
    @ObservationIgnored private let errorCategory: String?
    @ObservationIgnored private var pendingSaveTask: Task<Void, Never>?
    @ObservationIgnored private var lifecycleObservers: [NSObjectProtocol] = []

    init(
        url: URL,
        default defaultValue: T,
        debounce: Duration = .milliseconds(800),
        errorCategory: String? = nil,
        migrate: @escaping (Int, Data) throws -> T = { version, _ in
            throw SchemaMigrationError.unsupportedVersion(version, supported: T.schemaVersion)
        }
    ) {
        self.url = url
        self.rotator = BackupRotator(url: url)
        self.debounce = debounce
        self.errorCategory = errorCategory
        self.migrate = migrate

        if let loaded = Self.tryLoad(url: url, migrate: migrate) {
            self.value = loaded
        } else if let backup = BackupRotator(url: url).latestBackup(),
                  let loaded = Self.tryLoad(url: backup, migrate: migrate) {
            self.value = loaded
            // 메인 파일이 손상되어 백업으로 복원되었음을 알림.
            if let cat = errorCategory {
                ErrorBus.shared.publish(cat, "메인 데이터 파일이 손상되어 백업에서 복원했습니다.")
            }
        } else {
            self.value = defaultValue
        }

        installLifecycleObservers()
    }

    deinit {
        pendingSaveTask?.cancel()
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
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

    /// 디바운스를 무시하고 즉시 디스크에 동기적으로 기록.
    /// 종료·삭제 등 손실 비용이 큰 경로에서 사용.
    func flushSyncNow() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        do {
            try Self.persist(value: value, url: url, rotator: rotator)
            lastError = nil
        } catch {
            recordError(error)
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

    private func installLifecycleObservers() {
        // queue: nil → 알림이 게시된 스레드(메인)에서 동기 실행. 종료 시 run loop 가
        // 정리되더라도 즉시 디스크 기록이 보장됨.
        let names: [Notification.Name] = [
            NSApplication.willTerminateNotification,
            NSApplication.didResignActiveNotification
        ]
        for name in names {
            let observer = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.flushSyncNow()
                }
            }
            lifecycleObservers.append(observer)
        }
    }

    private func clearPendingAndError() {
        pendingSaveTask = nil
        lastError = nil
    }

    private func recordError(_ error: Error) {
        pendingSaveTask = nil
        lastError = error
        if let cat = errorCategory {
            ErrorBus.shared.publish(cat, "저장 실패: \(error.localizedDescription)")
        }
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

        // 무결성 검증: 방금 쓴 파일을 다시 읽어 디코딩 가능한지 확인.
        // 디스크 fill / FS 손상 등으로 데이터가 깨졌으면 즉시 throw.
        let written = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        _ = try decoder.decode(VersionedEnvelope<T>.self, from: written)

        try? rotator.rotate()
    }
}
