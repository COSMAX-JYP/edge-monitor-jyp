import Foundation

nonisolated enum HTTPMethod: String, Codable, CaseIterable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

nonisolated struct WebhookHeader: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var value: String

    init(id: UUID = UUID(), name: String, value: String) {
        self.id = id
        self.name = name
        self.value = value
    }
}

nonisolated enum AIProvider: String, Codable, CaseIterable, Sendable {
    case claude
    case codex
    case gemini

    var label: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex (OpenAI)"
        case .gemini: return "Gemini"
        }
    }

    var commandLine: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        case .gemini: return "gemini"
        }
    }
}

nonisolated indirect enum StreamDeckAction: Codable, Hashable, Sendable {
    case none
    case launchApp(bundleId: String)
    case openURL(url: String)
    case keystroke(modifiers: KeystrokeModifiers, key: String)
    case runShell(command: String, requireConfirm: Bool, timeoutSeconds: Int)
    case appleScript(source: String, requireConfirm: Bool)
    case pasteText(text: String, restoreClipboard: Bool)
    case webhook(url: String, method: HTTPMethod, headers: [WebhookHeader], body: String, requireConfirm: Bool)
    case aiPrompt(provider: AIProvider, prompt: String, timeoutSeconds: Int)
    case multi(actions: [StreamDeckAction], stopOnError: Bool)

    var summary: String {
        switch self {
        case .none: return "비어 있음"
        case .launchApp(let bundleId): return "앱 실행: \(bundleId)"
        case .openURL(let url): return "URL: \(url)"
        case .keystroke(let mods, let key): return "단축키: \(mods.symbol)\(key.uppercased())"
        case .runShell(let cmd, _, _): return "Shell: \(cmd.prefix(40))"
        case .appleScript(let src, _): return "AppleScript: \(src.prefix(40))"
        case .pasteText(let text, _): return "Paste: \(text.prefix(40))"
        case .webhook(let url, let method, _, _, _): return "\(method.rawValue) \(url.prefix(40))"
        case .aiPrompt(let provider, let prompt, _): return "\(provider.label): \(prompt.prefix(40))"
        case .multi(let actions, _): return "다중 액션 (\(actions.count)단계)"
        }
    }

    var kindLabel: String {
        switch self {
        case .none: return "없음"
        case .launchApp: return "앱 실행"
        case .openURL: return "URL 열기"
        case .keystroke: return "키보드 단축키"
        case .runShell: return "Shell 명령"
        case .appleScript: return "AppleScript"
        case .pasteText: return "텍스트 붙여넣기"
        case .webhook: return "Webhook"
        case .aiPrompt: return "AI 프롬프트"
        case .multi: return "다중 액션"
        }
    }

    var requiresConfirmation: Bool {
        switch self {
        case .runShell(_, let confirm, _): return confirm
        case .appleScript(_, let confirm): return confirm
        case .webhook(_, _, _, _, let confirm): return confirm
        case .multi(let actions, _):
            return actions.contains { $0.requiresConfirmation }
        default: return false
        }
    }

    var hasOutput: Bool {
        switch self {
        case .runShell, .appleScript, .webhook, .aiPrompt: return true
        case .multi(let actions, _): return actions.contains { $0.hasOutput }
        default: return false
        }
    }
}

nonisolated enum StreamDeckActionKind: String, CaseIterable, Codable, Sendable {
    case launchApp
    case openURL
    case keystroke
    case shell
    case appleScript
    case pasteText
    case webhook
    case aiPrompt
    case multi

    var label: String {
        switch self {
        case .launchApp: return "앱 실행"
        case .openURL: return "URL 열기"
        case .keystroke: return "키보드 단축키"
        case .shell: return "Shell 명령"
        case .appleScript: return "AppleScript"
        case .pasteText: return "텍스트 붙여넣기"
        case .webhook: return "Webhook"
        case .aiPrompt: return "AI 프롬프트"
        case .multi: return "다중 액션"
        }
    }

    var sfSymbol: String {
        switch self {
        case .launchApp: return "app.dashed"
        case .openURL: return "link"
        case .keystroke: return "keyboard"
        case .shell: return "terminal"
        case .appleScript: return "scroll"
        case .pasteText: return "doc.on.clipboard"
        case .webhook: return "network"
        case .aiPrompt: return "sparkles"
        case .multi: return "list.bullet.indent"
        }
    }
}
