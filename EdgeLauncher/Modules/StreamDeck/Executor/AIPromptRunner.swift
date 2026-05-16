import Foundation

enum AIPromptRunner {
    static func run(provider: AIProvider, prompt: String, timeoutSeconds: Int) async throws -> String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw ActionExecutorError.invalidInput("프롬프트가 비어 있습니다")
        }
        let cli = provider.commandLine
        guard let executableURL = resolveExecutable(named: cli) else {
            throw ActionExecutorError.aiCliMissing(cli)
        }
        let timeout = max(5, min(timeoutSeconds, 600))

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = executableURL
                proc.arguments = arguments(for: provider, prompt: trimmedPrompt)
                let outPipe = Pipe()
                let errPipe = Pipe()
                proc.standardOutput = outPipe
                proc.standardError = errPipe
                do {
                    try proc.run()
                } catch {
                    continuation.resume(throwing: ActionExecutorError.aiPromptFailed(error.localizedDescription))
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
                if proc.terminationStatus != 0 {
                    let combined = [outString, errString].filter { !$0.isEmpty }.joined(separator: "\n---\n")
                    continuation.resume(throwing: ActionExecutorError.aiPromptFailed(
                        "Exit \(proc.terminationStatus)\n\(combined)"
                    ))
                } else {
                    continuation.resume(returning: outString.isEmpty ? "(no output)" : outString)
                }
            }
        }
    }

    private static func arguments(for provider: AIProvider, prompt: String) -> [String] {
        switch provider {
        case .claude: return ["-p", prompt]
        case .codex: return ["exec", prompt]
        case .gemini: return ["-p", prompt]
        }
    }

    private static func resolveExecutable(named name: String) -> URL? {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin", "/usr/local/bin",
            "/usr/bin", "/bin",
            (NSHomeDirectory() as NSString).appendingPathComponent(".local/bin"),
            (NSHomeDirectory() as NSString).appendingPathComponent("bin")
        ]
        for dir in candidates {
            let url = URL(fileURLWithPath: dir).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: url.path) { return url }
        }
        let envPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "").components(separatedBy: ":")
        for dir in envPaths where !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: url.path) { return url }
        }
        return nil
    }
}
