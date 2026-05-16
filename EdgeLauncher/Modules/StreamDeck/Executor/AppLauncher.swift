import Foundation
import AppKit

enum AppLauncher {
    static func launch(bundleId: String) async throws {
        let normalized = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw ActionExecutorError.invalidInput("앱 bundle id 가 비어 있습니다") }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: normalized) else {
            throw ActionExecutorError.appNotFound(bundleId: normalized)
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
        } catch {
            throw ActionExecutorError.launchFailed(underlying: error)
        }
    }
}
