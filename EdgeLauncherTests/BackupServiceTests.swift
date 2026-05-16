import XCTest
@testable import EdgeLauncher

@MainActor
final class BackupServiceTests: XCTestCase {

    private var workingDir: URL!
    private var dataURL: URL!
    private var snapshotDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        workingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
        dataURL = workingDir.appendingPathComponent("kanban.json")
        snapshotDir = workingDir.appendingPathComponent(".snapshots", isDirectory: true)
        try "{\"boards\":[]}".write(to: dataURL, atomically: true, encoding: .utf8)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: workingDir)
        try await super.tearDown()
    }

    func test_snapshotIfNeeded_createsFileFirstTime() {
        let service = BackupService(dataURL: dataURL, snapshotDirectory: snapshotDir, retentionDays: 30)
        let url = service.snapshotIfNeeded()
        XCTAssertNotNil(url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url!.path))
    }

    func test_snapshotIfNeeded_skipsWhenSameDayExists() {
        let service = BackupService(dataURL: dataURL, snapshotDirectory: snapshotDir, retentionDays: 30)
        _ = service.snapshotIfNeeded()
        let second = service.snapshotIfNeeded()
        XCTAssertNil(second)
    }

    func test_sweep_removesExpired() {
        let service = BackupService(dataURL: dataURL, snapshotDirectory: snapshotDir, retentionDays: 30)
        let url = service.snapshotIfNeeded()!
        let old = Date().addingTimeInterval(-86400 * 60)
        try? FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: url.path)
        service.sweep()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func test_list_returnsSnapshots() {
        let service = BackupService(dataURL: dataURL, snapshotDirectory: snapshotDir, retentionDays: 30)
        _ = service.snapshotIfNeeded()
        XCTAssertEqual(service.list().count, 1)
    }
}
