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
        .windowResizability(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("탭") {
                ForEach(Array(env.registry.modules.enumerated()), id: \.element.id) { idx, module in
                    if idx < 9 {
                        Button(module.title) {
                            env.router.activate(module.id)
                        }
                        .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")), modifiers: .command)
                    }
                }
                Divider()
                Button("새로고침") {
                    NSApp.sendAction(Selector(("reload:")), to: nil, from: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(env)
        }
    }

    private func handleAppear() {
        configureMainWindow()

        NotificationCenter.default.addObserver(
            forName: .edgeMoveRequested,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                env.windowController.moveMainWindowToEdge()
            }
        }

        if UserDefaults.standard.object(forKey: "app.autoMoveOnLaunch") == nil {
            UserDefaults.standard.set(true, forKey: "app.autoMoveOnLaunch")
        }
        if UserDefaults.standard.object(forKey: "app.startInFullScreen") == nil {
            UserDefaults.standard.set(true, forKey: "app.startInFullScreen")
        }

        if UserDefaults.standard.bool(forKey: "app.autoMoveOnLaunch") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                Task { @MainActor in
                    env.windowController.moveMainWindowToEdge()
                    if UserDefaults.standard.bool(forKey: "app.startInFullScreen") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            env.windowController.toggleFullScreen()
                        }
                    }
                }
            }
        }
    }

    private func configureMainWindow() {
        DispatchQueue.main.async {
            guard let window = NSApp.mainWindow ?? NSApp.windows.first else { return }
            window.collectionBehavior.insert(.fullScreenPrimary)
            window.styleMask.insert(.resizable)
        }
    }
}
