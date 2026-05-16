import Foundation
import AppKit

@MainActor
enum TextPaster {
    static func paste(_ text: String, restoreClipboard: Bool) async throws {
        guard !text.isEmpty else { throw ActionExecutorError.invalidInput("붙여넣을 텍스트가 비어 있습니다") }
        let pasteboard = NSPasteboard.general

        var snapshot: [NSPasteboard.PasteboardType: Data] = [:]
        if restoreClipboard {
            for type in pasteboard.types ?? [] {
                if let data = pasteboard.data(forType: type) {
                    snapshot[type] = data
                }
            }
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        try await Task.sleep(for: .milliseconds(50))
        do {
            try await KeystrokeSender.send(modifiers: [.command], key: "v")
        } catch {
            if restoreClipboard {
                restorePasteboard(snapshot)
            }
            throw error
        }

        if restoreClipboard {
            try await Task.sleep(for: .milliseconds(150))
            restorePasteboard(snapshot)
        }
    }

    private static func restorePasteboard(_ snapshot: [NSPasteboard.PasteboardType: Data]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        for (type, data) in snapshot {
            pasteboard.setData(data, forType: type)
        }
    }
}
