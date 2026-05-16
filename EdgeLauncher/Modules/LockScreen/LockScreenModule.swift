import AppKit
import SwiftUI

/// Sidebar tile that immediately puts macOS into the lock screen when activated.
///
/// The actual lock work is delegated to `~/Applications/LockScreen.app`
/// (an `osacompile`-produced AppleScript app that runs `CGSession -suspend`).
/// We launch that helper via `NSWorkspace.openApplication` so EdgeLauncher's
/// sandbox doesn't need to spawn `/System` binaries directly.
struct LockScreenModule: EdgeModule {
    let id = "lock-screen"
    let title = "잠금"
    let iconName = "lock.fill"
    let supportsFullscreen = false

    var view: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            Text("잠금 화면으로 진입 중…")
                .font(.appBody)
                .foregroundStyle(.secondary)
            Text("잠금이 풀린 후 사이드바에서 다른 탭을 선택하세요.")
                .font(.appCallout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func didBecomeActive() {
        Self.triggerLock()
    }

    private static func triggerLock() {
        // 1순위: `~/Applications/LockScreen.app` (osacompile 로 만든 AppleScript 앱) 실행.
        //  - System Events 키스트로크는 호출자(앱)에게 자동화 권한을 요구하는데,
        //    EdgeLauncher 가 직접 osascript 를 띄우면 권한 전파 문제로 종종 무시된다.
        //  - 독립된 .app 헬퍼는 자기 자신 identifier 로 TCC 가 부여되므로 안정적.
        let path = (NSString("~/Applications/LockScreen.app") as String).expandingTildePath
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, error in
                if let error {
                    Task { @MainActor in
                        ErrorBus.shared.publish("잠금", "LockScreen.app 실행 실패: \(error.localizedDescription)")
                    }
                    Self.fallbackPmset()
                }
            }
            return
        }
        // 헬퍼 앱이 없으면 fallback.
        fallbackPmset()
    }

    private static func fallbackPmset() {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            p.arguments = ["displaysleepnow"]
            do {
                try p.run()
                p.waitUntilExit()
                if p.terminationStatus == 0 { return }
            } catch {}
            Task { @MainActor in
                ErrorBus.shared.publish("잠금", "잠금 실행 실패. ~/Applications/LockScreen.app 이 존재하고 손쉬운 사용/자동화 권한이 허용됐는지 확인하세요.")
            }
        }
    }
}

private extension String {
    var expandingTildePath: String {
        (self as NSString).expandingTildeInPath
    }
}
