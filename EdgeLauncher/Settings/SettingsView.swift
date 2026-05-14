import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment
    @AppStorage("app.autoMoveOnLaunch") private var autoMoveOnLaunch = true
    @AppStorage("app.startInFullScreen") private var startInFullScreen = true

    var body: some View {
        TabView {
            Form {
                Toggle("앱 실행 시 Xeneon Edge로 자동 이동", isOn: $autoMoveOnLaunch)
                Toggle("Edge 이동 시 자동 풀스크린", isOn: $startInFullScreen)
            }
            .padding(24)
            .tabItem { Label("일반", systemImage: "gearshape") }

            ModuleVisibilityView()
                .environmentObject(env.registry)
                .tabItem { Label("탭", systemImage: "rectangle.split.3x1") }
        }
        .frame(width: 520, height: 320)
    }
}
