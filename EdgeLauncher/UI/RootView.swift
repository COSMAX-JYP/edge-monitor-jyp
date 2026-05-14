import SwiftUI

struct RootView: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter

    var body: some View {
        VStack(spacing: 0) {
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
        HStack {
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(height: 28)
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
                    module.viewBuilder()
                        .opacity(router.activeID == module.id ? 1 : 0)
                        .allowsHitTesting(router.activeID == module.id)
                        .accessibilityHidden(router.activeID != module.id)
                }
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

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}
