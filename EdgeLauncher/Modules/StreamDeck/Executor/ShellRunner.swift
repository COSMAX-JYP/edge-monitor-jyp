import Foundation

enum ShellRunner {
    static func run(command: String, timeoutSeconds: Int) async throws -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ActionExecutorError.invalidInput("Shell 명령이 비어 있습니다") }
        let timeout = max(1, min(timeoutSeconds, 600))

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.launchPath = "/bin/sh"
                proc.arguments = ["-c", trimmed]
                let outPipe = Pipe()
                let errPipe = Pipe()
                proc.standardOutput = outPipe
                proc.standardError = errPipe
                do {
                    try proc.run()
                } catch {
                    continuation.resume(throwing: ActionExecutorError.shellFailed(error.localizedDescription))
                    return
                }
                let timer = DispatchSource.makeTimerSource(queue: .global())
                timer.schedule(deadline: .now() + .seconds(timeout))
                timer.setEventHandler { [weak proc] in
                    if let p = proc, p.isRunning { p.terminate() }
                }
                timer.resume()
                proc.waitUntilExit()
                timer.cancel()
                let out = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
                let err = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
                let outString = String(data: out, encoding: .utf8) ?? ""
                let errString = String(data: err, encoding: .utf8) ?? ""
                let combined = [outString, errString].filter { !$0.isEmpty }.joined(separator: "\n---\n")
                if proc.terminationStatus != 0 && combined.isEmpty {
                    continuation.resume(throwing: ActionExecutorError.shellFailed("Exit code \(proc.terminationStatus)"))
                } else {
                    continuation.resume(returning: combined.isEmpty ? "(no output)" : combined)
                }
            }
        }
    }
}
