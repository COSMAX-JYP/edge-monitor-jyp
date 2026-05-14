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
                .onAppear {
                    NotificationCenter.default.addObserver(
                        forName: .edgeMoveRequested,
                        object: nil,
                        queue: .main
                    ) { _ in
                        Task { @MainActor in
                            env.windowController.moveMainWindowToEdge()
                        }
                    }
                }
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(env)
        }
    }
}
