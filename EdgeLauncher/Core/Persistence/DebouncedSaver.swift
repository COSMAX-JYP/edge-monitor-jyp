import Foundation

actor DebouncedSaver {
    typealias Action = @Sendable () async throws -> Void

    private let interval: Duration
    private let action: Action
    private var pendingTask: Task<Void, Error>?

    init(interval: Duration, action: @escaping Action) {
        self.interval = interval
        self.action = action
    }

    func schedule() {
        pendingTask?.cancel()
        let interval = interval
        let action = action
        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: interval)
            try Task.checkCancellation()
            try await action()
            await self?.clearPending()
        }
    }

    func flush() async throws {
        pendingTask?.cancel()
        pendingTask = nil
        try await action()
    }

    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }

    private func clearPending() {
        pendingTask = nil
    }
}
