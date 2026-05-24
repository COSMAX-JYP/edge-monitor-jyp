import SwiftUI

struct KanbanSlidePanelView: View {
    @Bindable var viewModel: KanbanViewModel
    @Bindable var settings: KanbanSlidePanelSettings
    var onRequestClose: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView(.horizontal, showsIndicators: true) {
                // AppTypography 의 .app* 폰트가 32:9 Edge 용으로 크게 잡혀 있어
                // 좁은 패널에서는 카드/컬럼이 답답하다. 정공법(AppTypography 환경키)은
                // 후속 PR. 우선은 scaleEffect 로 시각 축소만 — hit-test 좌표는 SwiftUI
                // 가 transform 후 좌표를 따라간다.
                KanbanBoardView(viewModel: viewModel)
                    .frame(minWidth: 720, alignment: .leading)
                    .scaleEffect(slidePanelContentScale, anchor: .topLeading)
                    .frame(
                        width: 720 * slidePanelContentScale,
                        height: 1200 * slidePanelContentScale,
                        alignment: .topLeading
                    )
            }
            .background(.ultraThinMaterial)
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 0.65 = ~12pt 환산 (18pt × 0.65 ≈ 11.7pt). 추후 settings 로 가변화 가능.
    private var slidePanelContentScale: CGFloat { 0.65 }

    private var header: some View {
        HStack(spacing: 8) {
            BoardPickerView(viewModel: viewModel)
            Spacer()
            Button { settings.isPinned.toggle() } label: {
                Image(systemName: settings.isPinned ? "pin.fill" : "pin")
            }
            .help(settings.isPinned ? "핀 해제" : "핀")
            Button { onRequestClose() } label: { Image(systemName: "xmark") }
                .help("닫기")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
