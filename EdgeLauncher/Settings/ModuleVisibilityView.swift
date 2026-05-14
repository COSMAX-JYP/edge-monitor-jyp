import SwiftUI

struct ModuleVisibilityView: View {
    @EnvironmentObject var registry: ModuleRegistry

    var body: some View {
        Form {
            Section("표시할 탭") {
                ForEach(registry.modules) { module in
                    let isVisible = !registry.hiddenIDs.contains(module.id)
                    Toggle(isOn: Binding(
                        get: { isVisible },
                        set: { registry.setVisible(module.id, visible: $0) }
                    )) {
                        Label(module.title, systemImage: module.iconName)
                    }
                }
            }
            if registry.hiddenIDs.count == registry.modules.count {
                Section {
                    Label("모든 탭이 숨겨졌습니다. 적어도 하나 표시 권장.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(20)
    }
}
