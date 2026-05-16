import Foundation
import OSAKit

enum AppleScriptRunner {
    static func run(source: String) async throws -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ActionExecutorError.invalidInput("AppleScript 소스가 비어 있습니다") }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let script = OSAScript(source: trimmed)
                var error: NSDictionary?
                let result = script.executeAndReturnError(&error)
                if let err = error {
                    let msg = (err["NSAppleScriptErrorMessage"] as? String) ?? "AppleScript 실행 오류"
                    let code = (err["NSAppleScriptErrorNumber"] as? Int) ?? 0
                    if code == -1743 || code == -10004 {
                        continuation.resume(throwing: ActionExecutorError.automationNotAuthorized)
                    } else {
                        continuation.resume(throwing: ActionExecutorError.appleScriptFailed(msg))
                    }
                } else {
                    continuation.resume(returning: result?.stringValue ?? "(no output)")
                }
            }
        }
    }
}
