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
            CommandGroup(replacing: .newItem) {
                Button("New") { env.commandRouter.dispatch(.newItem) }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .pasteboard) {
                Button("Edit") { env.commandRouter.dispatch(.editItem) }
                    .keyboardShortcut("e", modifiers: .command)
                Button("Delete") { env.commandRouter.dispatch(.delete) }
                    .keyboardShortcut(.delete, modifiers: .command)
            }
            CommandGroup(after: .undoRedo) {
                Button("Find") { env.commandRouter.dispatch(.search) }
                    .keyboardShortcut("f", modifiers: .command)
            }
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
                    env.commandRouter.dispatch(.refresh)
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
        let didBootstrap = env.bootstrapWindowIfNeeded()

        if UserDefaults.standard.object(forKey: "app.autoMoveOnLaunch") == nil {
            UserDefaults.standard.set(true, forKey: "app.autoMoveOnLaunch")
        }
        if UserDefaults.standard.object(forKey: "app.startInFullScreen") == nil {
            UserDefaults.standard.set(true, forKey: "app.startInFullScreen")
        }
        if UserDefaults.standard.object(forKey: "app.keepCursorOnEdgeForTouch") == nil {
            UserDefaults.standard.set(true, forKey: "app.keepCursorOnEdgeForTouch")
        }

        if didBootstrap, UserDefaults.standard.bool(forKey: "app.autoMoveOnLaunch") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                Task { @MainActor in
                    env.windowController.moveMainWindowToEdge()
                    if UserDefaults.standard.bool(forKey: "app.startInFullScreen") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            env.windowController.enterFullScreenIfNeeded()
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
