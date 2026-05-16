import Foundation

@MainActor
enum MultiActionRunner {
    static func run(actions: [StreamDeckAction], stopOnError: Bool) async throws -> String {
        guard !actions.isEmpty else {
            throw ActionExecutorError.invalidInput("실행할 액션이 없습니다")
        }
        var outputs: [String] = []
        var lastError: Error?
        for (idx, action) in actions.enumerated() {
            let prefix = "[\(idx + 1)/\(actions.count)] \(action.kindLabel)"
            do {
                let result = try await ActionExecutor.run(action)
                if let out = result.output, !out.isEmpty {
                    outputs.append("\(prefix)\n\(out)")
                } else {
                    outputs.append("\(prefix) ✓")
                }
            } catch {
                outputs.append("\(prefix) ✗ \((error as? ActionExecutorError)?.errorDescription ?? error.localizedDescription)")
                lastError = error
                if stopOnError { break }
            }
        }
        let combined = outputs.joined(separator: "\n---\n")
        if let err = lastError, stopOnError {
            throw ActionExecutorError.multiActionFailed(combined, underlying: err)
        }
        return combined.isEmpty ? "(no output)" : combined
    }
}
