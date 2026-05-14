import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter
    @EnvironmentObject var displayService: XeneonDisplayService
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: 34))
                .padding(.vertical, 20)

            Divider()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
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
                .padding(.vertical, 10)
            }

            Spacer()

            Divider()

            VStack(spacing: 10) {
                Button(action: requestEdgeMove) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 30))
                        .frame(width: 78, height: 78)
                        .opacity(displayService.edgeScreen == nil ? 0.3 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(displayService.edgeScreen == nil)
                .help("Xeneon Edge로 이동")

                Button(action: { openSettings() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 30))
                        .frame(width: 78, height: 78)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)
        }
        .frame(width: 155)
        .background(.regularMaterial)
    }

    private func requestEdgeMove() {
        NotificationCenter.default.post(name: .edgeMoveRequested, object: nil)
    }
}
