import SwiftUI

@main
struct EdgeLauncherApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup("Edge Launcher") {
            RootView()
                .environmentObject(env.registry)
                .environmentObject(env.router)
                .environmentObject(env.displayService)
                .frame(minWidth: 1280, idealWidth: 2560, minHeight: 480, idealHeight: 720)
                .onAppear { handleAppear() }
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(env)
        }
    }

    private func handleAppear() {
        NotificationCenter.default.addObserver(
            forName: .edgeMoveRequested,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                env.windowController.moveMainWindowToEdge()
            }
        }

        if UserDefaults.standard.bool(forKey: "app.autoMoveOnLaunch") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Task { @MainActor in
                    env.windowController.moveMainWindowToEdge()
                    if UserDefaults.standard.bool(forKey: "app.startInFullScreen") {
                        env.windowController.toggleFullScreen()
                    }
                }
            }
        }
    }
}
