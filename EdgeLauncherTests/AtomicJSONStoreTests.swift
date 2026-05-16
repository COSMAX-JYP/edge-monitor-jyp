import XCTest
@testable import EdgeLauncher

struct AtomicJSONStoreSample: Codable, Equatable, Versioned {
    static var schemaVersion: Int { 1 }
    var counter: Int
    var label: String
}

@MainActor
final class AtomicJSONStoreTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AtomicJSONStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }

    func test_initialLoad_returnsDefaultWhenFileMissing() async {
        let store = AtomicJSONStore<AtomicJSONStoreSample>(
            url: tempDirectory.appendingPathComponent("missing.json"),
            default: AtomicJSONStoreSample(counter: 0, label: "default")
        )
        XCTAssertEqual(store.value, AtomicJSONStoreSample(counter: 0, label: "default"))
    }

    func test_flush_writesEnvelopeToDisk() async throws {
        let url = tempDirectory.appendingPathComponent("data.json")
        let store = AtomicJSONStore<AtomicJSONStoreSample>(url: url, default: AtomicJSONStoreSample(counter: 0, label: ""))
        store.update { $0.counter = 5; $0.label = "five" }
        try await store.flush()

        let data = try Data(contentsOf: url)
        let envelope = try JSONDecoder().decode(VersionedEnvelope<AtomicJSONStoreSample>.self, from: data)
        XCTAssertEqual(envelope.schemaVersion, AtomicJSONStoreSample.schemaVersion)
        XCTAssertEqual(envelope.payload, AtomicJSONStoreSample(counter: 5, label: "five"))
    }

    func test_reload_readsExistingFile() async throws {
        let url = tempDirectory.appendingPathComponent("data.json")
        let payload = VersionedEnvelope(payload: AtomicJSONStoreSample(counter: 7, label: "seven"))
        let data = try JSONEncoder().encode(payload)
        try AtomicFileWriter.write(data, to: url)

        let store = AtomicJSONStore<AtomicJSONStoreSample>(url: url, default: AtomicJSONStoreSample(counter: 0, label: ""))
        XCTAssertEqual(store.value, AtomicJSONStoreSample(counter: 7, label: "seven"))
    }

    func test_backup_isRotatedOnSave() async throws {
        let url = tempDirectory.appendingPathComponent("data.json")
        let store = AtomicJSONStore<AtomicJSONStoreSample>(url: url, default: AtomicJSONStoreSample(counter: 0, label: ""))
        store.update { $0.counter = 1 }
        try await store.flush()
        store.update { $0.counter = 2 }
        try await store.flush()

        let backup1 = url.deletingLastPathComponent()
            .appendingPathComponent("data.json.bak.1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup1.path))
    }

    func test_corruptedFile_fallsBackToBackup() async throws {
        let url = tempDirectory.appendingPathComponent("data.json")
        let store = AtomicJSONStore<AtomicJSONStoreSample>(url: url, default: AtomicJSONStoreSample(counter: 0, label: ""))
        store.update { $0.counter = 9; $0.label = "nine" }
        try await store.flush()

        try "not json".write(to: url, atomically: true, encoding: .utf8)

        let restored = AtomicJSONStore<AtomicJSONStoreSample>(url: url, default: AtomicJSONStoreSample(counter: 0, label: "default"))
        XCTAssertEqual(restored.value.counter, 9)
        XCTAssertEqual(restored.value.label, "nine")
    }

}
