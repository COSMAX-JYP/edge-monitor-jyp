import SwiftUI

struct KanbanSlidePanelView: View {
    @Bindable var viewModel: KanbanViewModel
    @Bindable var settings: KanbanSlidePanelSettings
    var onRequestClose: () -> Void = {}

    /// 컬럼별 드래그 시작 시점의 폭 스냅샷. key = column.id.
    @State private var columnResizeBases: [UUID: Double] = [:]

    /// 컬럼별 폭 mirror — settings.columnWidth(for:) 가 UserDefaults backing 이라
    /// @Observable 자동 추적 불가. drag/버튼 변경 시 mirror 갱신하여 즉시 재계산.
    @State private var columnWidthMirrors: [UUID: Double] = [:]

    /// 헤더 ± 버튼이 변경하는 fallback panelColumnWidth 미러. 컬럼별 override 없는
    /// 컬럼들에 적용.
    @State private var fallbackColumnWidthMirror: Double?

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
                    maxColumnWidth: CGFloat(settings.panelColumnWidth + 60),
                    onColumnWidthDrag: { columnId, dx, isEnded in
                        let storedBase = settings.columnWidth(for: columnId)
                        let base = columnResizeBases[columnId] ?? storedBase
                        if columnResizeBases[columnId] == nil {
                            columnResizeBases[columnId] = base
                        }
                        let next = base + Double(dx) / Double(s)
                        let clamped = max(
                            KanbanSlidePanelSettings.minPanelColumnWidth,
                            min(KanbanSlidePanelSettings.maxPanelColumnWidth, next)
                        )
                        // drag 중에는 mirror 만 갱신해 SwiftUI 재계산 트리거. UserDefaults
                        // write 는 drag 종료 시점에만 1회 (60Hz 의 UserDefaults.set spam 회피).
                        columnWidthMirrors[columnId] = clamped
                        if isEnded {
                            settings.setColumnWidth(clamped, for: columnId)
                            columnResizeBases[columnId] = nil
                        }
                    },
                    columnWidthOverride: { columnId in
                        if let m = columnWidthMirrors[columnId] { return CGFloat(m) }
                        // 컬럼별 override 가 settings 에 저장돼 있으면 사용, 아니면 fallback.
                        let map = (UserDefaults.standard.dictionary(forKey: "slidepanel.columnWidths") as? [String: Double]) ?? [:]
                        if let stored = map[columnId.uuidString] { return CGFloat(stored) }
                        return CGFloat(fallbackColumnWidthMirror ?? settings.panelColumnWidth)
                    }
                )
                .frame(width: proxy.size.width / s, height: proxy.size.height / s, alignment: .topLeading)
                .scaleEffect(s, anchor: .topLeading)
            }
        }
        .background(.thinMaterial)  // 이중 material(.thin + .ultraThin) 제거 → 렌더링 비용 절감
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 0.624 = AppTypography 18pt → 11.2pt 환산. drag 는 NSEvent.localMonitor 가
    /// 처리하므로 scaleEffect 와 무관.
    private var slidePanelContentScale: CGFloat { 0.624 }

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

    /// 패널 헤더에서 즉시 컬럼 폭 조정 + 자동 저장. 컬럼별 override 가 없는 컬럼들에만
    /// 영향 (fallback 일괄 변경). 개별 컬럼은 우측 가장자리 드래그로 조정.
    private var columnWidthControl: some View {
        HStack(spacing: 4) {
            Button {
                let next = max(
                    KanbanSlidePanelSettings.minPanelColumnWidth,
                    settings.panelColumnWidth - 20
                )
                settings.panelColumnWidth = next
                fallbackColumnWidthMirror = next
            } label: { Image(systemName: "minus.rectangle") }
            .help("컬럼 좁게")

            Button {
                let next = min(
                    KanbanSlidePanelSettings.maxPanelColumnWidth,
                    settings.panelColumnWidth + 20
                )
                settings.panelColumnWidth = next
                fallbackColumnWidthMirror = next
            } label: { Image(systemName: "plus.rectangle") }
            .help("컬럼 넓게")
        }
    }
}
