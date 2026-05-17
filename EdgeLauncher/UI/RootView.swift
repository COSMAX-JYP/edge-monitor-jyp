import SwiftUI

struct RootView: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter
    @EnvironmentObject var displayService: XeneonDisplayService
    @Environment(\.openSettings) private var openSettings
    @AppStorage("app.themeMode") private var themeMode = "dark"
    @State private var activated: Set<String> = []
    @State private var editingIconModuleID: String?

    var body: some View {
        ZStack {
            EdgeTheme.appBackground(isLight: isLightTheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ErrorBanner(bus: ErrorBus.shared)
                statusStrip
                HStack(spacing: 0) {
                    Sidebar()
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            Rectangle()
                                .fill(EdgeTheme.panelFill(isLight: isLightTheme).opacity(isLightTheme ? 0.36 : 0.30))
                                .overlay(alignment: .leading) {
                                    Rectangle()
                                        .fill(EdgeTheme.stroke(isLight: isLightTheme))
                                        .frame(width: 1)
                                }
                        )
                }
            }
        }
        .frame(minWidth: 1792, minHeight: 672)
        .preferredColorScheme(isLightTheme ? .light : .dark)
        .animation(.easeInOut(duration: 0.18), value: router.activeID)
        .animation(.easeInOut(duration: 0.20), value: themeMode)
        .onReceive(NotificationCenter.default.publisher(for: .moduleIconEditorRequested)) { note in
            editingIconModuleID = note.userInfo?["moduleID"] as? String
        }
        .dismissiblePopup(item: iconEditorBinding) { module in
            ModuleIconEditorSheet(
                moduleID: module.id,
                title: module.title,
                systemIconName: module.iconName,
                initialCustomization: registry.iconCustomization(for: module.id),
                onClose: { editingIconModuleID = nil }
            )
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.split.3x1.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(EdgeTheme.cyan)
                Text("EdgeLauncher")
                    .font(.system(size: 13, weight: .bold))
                Text("v\(Self.appVersion)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Designed by jyp")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            EdgeIconButton(
                systemName: isLightTheme ? "moon.fill" : "sun.max.fill",
                help: isLightTheme ? "다크 테마로 전환" : "화이트 테마로 전환",
                isLight: isLightTheme,
                action: toggleTheme
            )

            EdgeIconButton(
                systemName: "rectangle.portrait.and.arrow.right",
                help: "Xeneon Edge로 이동",
                isLight: isLightTheme,
                isDisabled: displayService.edgeScreen == nil,
                action: requestEdgeMove
            )

            EdgeIconButton(
                systemName: "gearshape.fill",
                help: "설정",
                isLight: isLightTheme,
                action: { openSettings() }
            )
        }
        .padding(.horizontal, 12)
        .frame(height: EdgeTheme.statusHeight)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EdgeTheme.stroke(isLight: isLightTheme))
                .frame(height: 1)
        }
    }

    // WebView처럼 세션/재생 유지가 필요한 모듈만 비활성 상태에서도 살려둔다.
    @ViewBuilder
    private var content: some View {
        if registry.modules.isEmpty {
            placeholder
        } else {
            ZStack {
                ForEach(registry.modules) { module in
                    let isActive = router.activeID == module.id
                    let shouldRender = isActive || (module.preservesInactiveRendering && activated.contains(module.id))
                    if shouldRender {
                        module.viewBuilder()
                            .opacity(isActive ? 1 : 0)
                            .allowsHitTesting(isActive)
                            .accessibilityHidden(!isActive)
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
                .font(.appBody)
                .foregroundStyle(.secondary)
        }
    }

    private func requestEdgeMove() {
        NotificationCenter.default.post(name: .edgeMoveRequested, object: nil)
    }

    private var isLightTheme: Bool {
        themeMode == "light"
    }

    private var iconEditorBinding: Binding<AnyEdgeModule?> {
        Binding(
            get: {
                guard let id = editingIconModuleID else { return nil }
                return registry.module(id: id)
            },
            set: { module in
                editingIconModuleID = module?.id
            }
        )
    }

    private func toggleTheme() {
        themeMode = isLightTheme ? "dark" : "light"
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}

extension Notification.Name {
    static let moduleIconEditorRequested = Notification.Name("edge.module.iconEditorRequested")
}
