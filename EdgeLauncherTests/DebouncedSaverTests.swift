import XCTest
@testable import EdgeLauncher

final class DebouncedSaverTests: XCTestCase {

    func test_scheduleRunsActionOnce_afterInterval() async throws {
        let counter = Counter()
        let saver = DebouncedSaver(interval: .milliseconds(50)) {
            await counter.increment()
        }

        await saver.schedule()
        try await Task.sleep(for: .milliseconds(150))

        let result = await counter.value
        XCTAssertEqual(result, 1)
    }

    func test_rapidSchedule_collapsesIntoSingleRun() async throws {
        let counter = Counter()
        let saver = DebouncedSaver(interval: .milliseconds(80)) {
            await counter.increment()
        }

        for _ in 0..<5 {
            await saver.schedule()
            try await Task.sleep(for: .milliseconds(10))
        }
        try await Task.sleep(for: .milliseconds(200))

        let result = await counter.value
        XCTAssertEqual(result, 1)
    }

    func test_flush_runsImmediately() async throws {
        let counter = Counter()
        let saver = DebouncedSaver(interval: .seconds(10)) {
            await counter.increment()
        }

        try await saver.flush()
        let result = await counter.value
        XCTAssertEqual(result, 1)
    }

    func test_cancel_preventsRun() async throws {
        let counter = Counter()
        let saver = DebouncedSaver(interval: .milliseconds(50)) {
            await counter.increment()
        }

        await saver.schedule()
        await saver.cancel()
        try await Task.sleep(for: .milliseconds(150))

        let result = await counter.value
        XCTAssertEqual(result, 0)
    }

    func test_flushPropagatesError() async {
        let saver = DebouncedSaver(interval: .seconds(10)) {
            throw NSError(domain: "test", code: 1)
        }

        do {
            try await saver.flush()
            XCTFail("expected throw")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "test")
        }
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}
