import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment
    @AppStorage("app.autoMoveOnLaunch") private var autoMoveOnLaunch = true
    @AppStorage("app.startInFullScreen") private var startInFullScreen = true
    @AppStorage("app.keepCursorOnEdgeForTouch") private var keepCursorOnEdgeForTouch = true

    var body: some View {
        TabView {
            Form {
                Toggle("앱 실행 시 Xeneon Edge로 자동 이동", isOn: $autoMoveOnLaunch)
                Toggle("Edge 이동 시 자동 풀스크린", isOn: $startInFullScreen)
                Toggle("Edge 터치/클릭 시 커서를 Edge 화면으로 이동", isOn: $keepCursorOnEdgeForTouch)
            }
            .font(.appBody)
            .padding(28)
            .tabItem { Label("일반", systemImage: "gearshape") }

            DiscordInstancesSettingsView()
                .tabItem { Label("Discord", systemImage: "bubble.left.and.bubble.right.fill") }

            ModuleVisibilityView()
                .environmentObject(env.registry)
                .tabItem { Label("탭", systemImage: "rectangle.split.3x1") }
        }
        // Edge 디스플레이(720pt) 의 85% = 612pt 로 고정. 가로는 Edge 가 2560 으로 넉넉하므로 1100 이상.
        .frame(minWidth: 900, idealWidth: 1400, maxWidth: 2000, minHeight: 540, idealHeight: 612, maxHeight: 612)
    }
}
