import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter
    @ObservedObject private var badges = BadgeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: 34))
                .padding(.vertical, 20)

            Divider()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(registry.visibleModules) { module in
                        TouchableTabButton(
                            iconName: module.iconName,
                            title: module.title,
                            isActive: router.activeID == module.id,
                            badgeCount: badges.counts[module.id] ?? 0
                        ) {
                            router.activate(module.id)
                        }
                    }
                }
                .padding(.vertical, 10)
            }

            Spacer()
        }
        .frame(width: 155)
        .background(.regularMaterial)
    }
}
