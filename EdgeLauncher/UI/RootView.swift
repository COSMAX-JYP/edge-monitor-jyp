import SwiftUI

struct RootView: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter
    @EnvironmentObject var displayService: XeneonDisplayService
    @Environment(\.openSettings) private var openSettings
    @State private var activated: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            ErrorBanner(bus: ErrorBus.shared)
            headerBar
            Divider()
            HStack(spacing: 0) {
                Sidebar()
                Divider()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 1280, minHeight: 480)
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.split.3x1.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("EdgeLauncher")
                    .font(.system(size: 11, weight: .semibold))
                Text("v\(Self.appVersion)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Designed by jyp")
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(.tertiary)

            HStack(spacing: 4) {
                Button(action: requestEdgeMove) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 22)
                        .opacity(displayService.edgeScreen == nil ? 0.3 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(displayService.edgeScreen == nil)
                .help("Xeneon Edge로 이동")

                Button(action: { openSettings() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 22)
                }
                .buttonStyle(.plain)
                .help("설정")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: 32)
        .background(.regularMaterial)
    }

    // 모든 등록 모듈을 항상 렌더링하고 활성 모듈만 가시화한다.
    // WKWebView 등 미디어 뷰는 비활성 상태에서도 살아있어 백그라운드 재생을 유지.
    @ViewBuilder
    private var content: some View {
        if registry.modules.isEmpty {
            placeholder
        } else {
            ZStack {
                ForEach(registry.modules) { module in
                    if activated.contains(module.id) {
                        module.viewBuilder()
                            .opacity(router.activeID == module.id ? 1 : 0)
                            .allowsHitTesting(router.activeID == module.id)
                            .accessibilityHidden(router.activeID != module.id)
                    }
                }
            }
            .onAppear {
                if let id = router.activeID { activated.insert(id) }
            }
            .onChange(of: router.activeID) { _, newID in
                if let id = newID { activated.insert(id) }
            }
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

    private func requestEdgeMove() {
        NotificationCenter.default.post(name: .edgeMoveRequested, object: nil)
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}
