import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: 24))
                .padding(.vertical, 16)

            Divider()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(registry.modules) { module in
                        TouchableTabButton(
                            iconName: module.iconName,
                            title: module.title,
                            isActive: router.activeID == module.id
                        ) {
                            router.activate(module.id)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()

            Divider()

            Button(action: { openSettings() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 22))
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .frame(width: 110)
        .background(.regularMaterial)
    }
}
