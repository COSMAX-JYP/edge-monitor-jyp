import SwiftUI

struct KanbanSlidePanelView: View {
    @Bindable var viewModel: KanbanViewModel
    @Bindable var settings: KanbanSlidePanelSettings
    var onRequestClose: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            // SlidePad 전용으로 KanbanBoardView 에 좁은 컬럼 폭 override 주입.
            // AppTypography 의 .app* 폰트가 32:9 Edge 용으로 크게(18pt) 잡혀
            // 있어 좁은 패널에서는 답답하다. scaleEffect 로 시각 축소 — SwiftUI
            // 가 hit-test 좌표를 transform 후 좌표로 잡아주므로 클릭 정확도 유지.
            // GeometryReader 로 외곽 사이즈 받아서 KanbanBoardView 의 frame 을 1/scale
            // 만큼 키운 뒤 scaleEffect 로 그 비율만큼 축소 → 결과적으로 GeometryReader
            // 부모와 동일 폭/높이를 차지하되 내부 컨텐츠는 더 큰 좌표계로 그려지므로
            // 폰트가 시각적으로 줄어든 효과.
            GeometryReader { proxy in
                let s = slidePanelContentScale
                KanbanBoardView(
                    viewModel: viewModel,
                    minColumnWidth: CGFloat(settings.panelColumnWidth),
                    maxColumnWidth: CGFloat(settings.panelColumnWidth + 60)
                )
                .frame(width: proxy.size.width / s, height: proxy.size.height / s, alignment: .topLeading)
                .scaleEffect(s, anchor: .topLeading)
            }
            .background(.ultraThinMaterial)
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 0.52 = AppTypography 18pt → 9.4pt 환산. 사용자 요청 "전체 폰트 -20%" 반영
    /// (이전 0.65 에서 0.65 × 0.80 = 0.52).
    private var slidePanelContentScale: CGFloat { 0.52 }

    private var header: some View {
        HStack(spacing: 8) {
            BoardPickerView(viewModel: viewModel)
            Spacer()
            columnWidthControl
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

    /// 패널 헤더에서 즉시 컬럼 폭 조정 + 자동 저장.
    private var columnWidthControl: some View {
        HStack(spacing: 4) {
            Button {
                settings.panelColumnWidth = max(
                    KanbanSlidePanelSettings.minPanelColumnWidth,
                    settings.panelColumnWidth - 20
                )
            } label: { Image(systemName: "minus.rectangle") }
            .help("컬럼 좁게")

            Button {
                settings.panelColumnWidth = min(
                    KanbanSlidePanelSettings.maxPanelColumnWidth,
                    settings.panelColumnWidth + 20
                )
            } label: { Image(systemName: "plus.rectangle") }
            .help("컬럼 넓게")
        }
    }
}
