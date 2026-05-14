import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter
    @ObservedObject private var badges = BadgeStore.shared

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TouchScrollContainer {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(registry.visibleModules) { module in
                        TouchableTabButton(
                            iconName: module.iconName,
                            title: module.title,
                            isActive: router.activeID == module.id,
                            badgeCount: badges.counts[module.id] ?? 0
                        ) {
                            router.activate(module.id)
                        }
                        .contextMenu { reorderMenu(for: module.id) }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }

            Spacer()
        }
        .frame(width: 260)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func reorderMenu(for id: String) -> some View {
        if let idx = registry.modules.firstIndex(where: { $0.id == id }) {
            let lastIdx = registry.modules.count - 1
            Button("위로 이동") { registry.reorder(from: idx, to: idx - 1) }
                .disabled(idx == 0)
            Button("아래로 이동") { registry.reorder(from: idx, to: idx + 1) }
                .disabled(idx >= lastIdx)
            Divider()
            Button("맨 위로") { registry.reorder(from: idx, to: 0) }
                .disabled(idx == 0)
            Button("맨 아래로") { registry.reorder(from: idx, to: lastIdx) }
                .disabled(idx >= lastIdx)
            Divider()
            Button("이 탭 숨기기") { registry.setVisible(id, visible: false) }
        }
    }
}
