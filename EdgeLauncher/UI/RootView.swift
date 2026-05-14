import SwiftUI

struct RootView: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1280, minHeight: 480)
    }

    @ViewBuilder
    private var content: some View {
        if let id = router.activeID, let module = registry.module(id: id) {
            module.viewBuilder()
                .id(module.id)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.split.2x1")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("좌측에서 탭을 선택하세요")
                .foregroundStyle(.secondary)
        }
    }
}
