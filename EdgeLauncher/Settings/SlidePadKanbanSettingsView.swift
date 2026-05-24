import SwiftUI
import AppKit

struct SlidePadKanbanSettingsView: View {
    @EnvironmentObject var env: AppEnvironment
    @Bindable var settings: KanbanSlidePanelSettings

    var body: some View {
        Form {
            Section("동작") {
                HStack {
                    Text("패널 폭")
                    Slider(value: $settings.panelWidth,
                           in: KanbanSlidePanelSettings.minPanelWidth...KanbanSlidePanelSettings.maxPanelWidth,
                           step: 10)
                    Text("\(Int(settings.panelWidth)) pt").monospacedDigit().frame(width: 70, alignment: .trailing)
                }
                HStack {
                    Text("애니메이션 길이")
                    Slider(value: $settings.slideAnimationDuration,
                           in: KanbanSlidePanelSettings.minAnimationDuration...KanbanSlidePanelSettings.maxAnimationDuration,
                           step: 0.01)
                    Text(String(format: "%.2f s", settings.slideAnimationDuration))
                        .monospacedDigit().frame(width: 70, alignment: .trailing)
                }
                Picker("타깃 디스플레이", selection: Binding(
                    get: { settings.targetDisplayPolicy.rawValue },
                    set: { newRaw in
                        if let p = SlidePanelDisplayPolicy(rawValue: newRaw) { settings.targetDisplayPolicy = p }
                    }
                )) {
                    Text("마우스 위치").tag("mouse")
                    Text("메인 디스플레이").tag("main")
                    ForEach(NSScreen.screens, id: \.self) { screen in
                        let uuid = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
                        if let uuid {
                            Text(screen.localizedName).tag("uuid:\(uuid)")
                        }
                    }
                }
                Toggle("외부 클릭 시 자동 숨김", isOn: $settings.autoHideOnBlur)
                Toggle("Esc 키로 닫기", isOn: $settings.autoHideOnEscape)
                Toggle("핀 (자동 숨김 끄기)", isOn: $settings.isPinned)
            }
            Section("단축키") {
                Text("현재 단축키: Cmd + Shift + K (v2 에서는 고정).")
                    .font(.caption).foregroundStyle(.secondary)
                if env.slidePanelHotKey.lastError != nil {
                    Label("단축키 등록 실패. View 메뉴로 호출 가능.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                Text("사용자 정의 단축키 UI 는 후속 PR.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("패널 호출") {
                Button("SlidePad 칸반 토글") { env.slidePanelController.toggle() }
            }
        }
        .padding(28)
    }
}
