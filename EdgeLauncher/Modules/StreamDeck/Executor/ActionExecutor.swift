import Foundation

enum ActionExecutorError: Error, LocalizedError {
    case invalidInput(String)
    case appNotFound(bundleId: String)
    case launchFailed(underlying: Error)
    case openURLFailed(url: URL)
    case accessibilityNotAuthorized
    case automationNotAuthorized
    case secureInputBlocked
    case keystrokeFailed(String)
    case shellFailed(String)
    case appleScriptFailed(String)
    case webhookFailed(String)
    case aiCliMissing(String)
    case aiPromptFailed(String)
    case multiActionFailed(String, underlying: Error)
    case noAction

    var errorDescription: String? {
        switch self {
        case .invalidInput(let msg): return msg
        case .appNotFound(let id): return "앱을 찾을 수 없습니다: \(id)"
        case .launchFailed(let err): return "앱 실행 실패: \(err.localizedDescription)"
        case .openURLFailed(let url): return "URL 열기 실패: \(url.absoluteString)"
        case .accessibilityNotAuthorized: return "손쉬운 사용 권한이 필요합니다."
        case .automationNotAuthorized: return "자동화 권한이 필요합니다."
        case .secureInputBlocked: return "Secure Input 이 활성화되어 단축키를 전송할 수 없습니다."
        case .keystrokeFailed(let msg): return msg
        case .shellFailed(let msg): return "Shell 실패: \(msg)"
        case .appleScriptFailed(let msg): return "AppleScript 실패: \(msg)"
        case .webhookFailed(let msg): return "Webhook 실패: \(msg)"
        case .aiCliMissing(let cli): return "AI CLI 를 찾을 수 없습니다: \(cli)"
        case .aiPromptFailed(let msg): return "AI 프롬프트 실패: \(msg)"
        case .multiActionFailed(let msg, let err):
            return "\(msg)\n\(err.localizedDescription)"
        case .noAction: return "이 버튼은 액션이 설정되지 않았습니다."
        }
    }
}

struct ActionExecutionResult: Sendable {
    let output: String?
    var hasOutput: Bool { output != nil && !(output ?? "").isEmpty }
}

@MainActor
enum ActionExecutor {
    static func run(_ action: StreamDeckAction) async throws -> ActionExecutionResult {
        switch action {
        case .none:
            throw ActionExecutorError.noAction
        case .launchApp(let bundleId):
            try await AppLauncher.launch(bundleId: bundleId)
            return ActionExecutionResult(output: nil)
        case .openURL(let url):
            try await URLOpener.open(urlString: url)
            return ActionExecutionResult(output: nil)
        case .keystroke(let modifiers, let key):
            try await KeystrokeSender.send(modifiers: modifiers, key: key)
            return ActionExecutionResult(output: nil)
        case .runShell(let cmd, _, let timeout):
            let output = try await ShellRunner.run(command: cmd, timeoutSeconds: timeout)
            return ActionExecutionResult(output: output)
        case .appleScript(let source, _):
            let output = try await AppleScriptRunner.run(source: source)
            return ActionExecutionResult(output: output)
        case .pasteText(let text, let restore):
            try await TextPaster.paste(text, restoreClipboard: restore)
            return ActionExecutionResult(output: nil)
        case .webhook(let url, let method, let headers, let body, _):
            let output = try await WebhookCaller.call(urlString: url, method: method, headers: headers, body: body)
            return ActionExecutionResult(output: output)
        case .aiPrompt(let provider, let prompt, let timeout):
            let output = try await AIPromptRunner.run(provider: provider, prompt: prompt, timeoutSeconds: timeout)
            return ActionExecutionResult(output: output)
        case .multi(let actions, let stopOnError):
            let output = try await MultiActionRunner.run(actions: actions, stopOnError: stopOnError)
            return ActionExecutionResult(output: output)
        }
    }
}
