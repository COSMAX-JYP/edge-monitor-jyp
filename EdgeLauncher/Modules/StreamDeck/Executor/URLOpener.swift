import Foundation
import AppKit

enum URLOpener {
    static func open(urlString: String) async throws {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ActionExecutorError.invalidInput("URL 이 비어 있습니다") }
        guard let url = URL(string: trimmed) else {
            throw ActionExecutorError.invalidInput("올바르지 않은 URL: \(trimmed)")
        }
        if !NSWorkspace.shared.open(url) {
            throw ActionExecutorError.openURLFailed(url: url)
        }
    }
}
