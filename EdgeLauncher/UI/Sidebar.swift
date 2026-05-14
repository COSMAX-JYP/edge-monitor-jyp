import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter
    @EnvironmentObject var displayService: XeneonDisplayService
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

            VStack(spacing: 8) {
                Button(action: requestEdgeMove) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 22))
                        .frame(width: 56, height: 56)
                        .opacity(displayService.edgeScreen == nil ? 0.3 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(displayService.edgeScreen == nil)
                .help("Xeneon Edge로 이동")

                Button(action: { openSettings() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)
        }
        .frame(width: 110)
        .background(.regularMaterial)
    }

    private func requestEdgeMove() {
        NotificationCenter.default.post(name: .edgeMoveRequested, object: nil)
    }
}
