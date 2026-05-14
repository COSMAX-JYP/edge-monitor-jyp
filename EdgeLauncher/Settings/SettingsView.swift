import SwiftUI

struct SettingsView: View {
    @AppStorage("app.autoMoveOnLaunch") private var autoMoveOnLaunch = false
    @AppStorage("app.startInFullScreen") private var startInFullScreen = false

    var body: some View {
        TabView {
            Form {
                Toggle("앱 실행 시 Xeneon Edge로 자동 이동", isOn: $autoMoveOnLaunch)
                Toggle("Edge 이동 시 자동 풀스크린", isOn: $startInFullScreen)
            }
            .padding(24)
            .tabItem { Label("일반", systemImage: "gearshape") }

            Form {
                Text("탭 순서 편집은 다음 릴리스에서 지원합니다.")
            }
            .padding(24)
            .tabItem { Label("탭", systemImage: "rectangle.split.3x1") }
        }
        .frame(width: 520, height: 280)
    }
}
