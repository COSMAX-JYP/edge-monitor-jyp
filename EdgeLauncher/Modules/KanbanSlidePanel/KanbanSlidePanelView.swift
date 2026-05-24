import SwiftUI

struct KanbanSlidePanelView: View {
    @Bindable var viewModel: KanbanViewModel
    @Bindable var settings: KanbanSlidePanelSettings
    var onRequestClose: () -> Void = {}
    /// 헤더의 "화면 폭으로" 버튼 콜백. Controller 가 NSScreen 폭으로 panel.setFrame.
    var onResizeFullWidth: () -> Void = {}

    /// 컬럼별 드래그 시작 시점의 폭 스냅샷. key = column.id.
    @State private var columnResizeBases: [UUID: Double] = [:]

    /// 컬럼별 폭 mirror — settings.columnWidth(for:) 가 UserDefaults backing 이라
    /// @Observable 자동 추적 불가. drag/버튼 변경 시 mirror 갱신하여 즉시 재계산.
    @State private var columnWidthMirrors: [UUID: Double] = [:]

    /// 헤더 ± 버튼이 변경하는 fallback panelColumnWidth 미러. 컬럼별 override 없는
    /// 컬럼들에 적용.
    @State private var fallbackColumnWidthMirror: Double?

    /// settings.darkMode 미러 — UserDefaults backing 의 @Observable 미추적 우회.
    @State private var darkModeMirror: Bool?

    private var effectiveDarkMode: Bool { darkModeMirror ?? settings.darkMode }

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
        // A(Linear Dark) + D(Compact Dense) 하이브리드. SlidePad 전용 — 메인 윈도우는 미영향.
        // darkMode 토글로 라이트 모드도 지원.
        .background(
            effectiveDarkMode
                ? Color(red: 0.051, green: 0.055, blue: 0.071) // #0d0e12
                : Color(red: 0.97, green: 0.97, blue: 0.97)    // #f7f7f7
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .preferredColorScheme(effectiveDarkMode ? .dark : .light)
        .environment(\.colorScheme, effectiveDarkMode ? .dark : .light)
        .environment(\.isSlidePadStyle, true)  // Compact Dense — outline/shadow 약화, spacing 압축
    }

    /// 0.624 = AppTypography 18pt → 11.2pt 환산. drag 는 NSEvent.localMonitor 가
    /// 처리하므로 scaleEffect 와 무관.
    private var slidePanelContentScale: CGFloat { 0.624 }

    private var header: some View {
        HStack(spacing: 8) {
            BoardPickerView(viewModel: viewModel)
            Spacer()
            columnWidthControl

            // 시선이 한 번에 잡히도록 채워진 오렌지 배경 + 화살표 아이콘 + 라벨.
            Button(action: onResizeFullWidth) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.and.right")
                    Text("화면 폭")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(red: 1.0, green: 0.45, blue: 0.10)) // bright orange
                )
            }
            .buttonStyle(.plain)
            .help("패널 폭을 현재 화면 가로 해상도로 재조정")

            Button {
                let next = !settings.darkMode
                settings.darkMode = next
                darkModeMirror = next
            } label: {
                Image(systemName: effectiveDarkMode ? "moon.fill" : "sun.max.fill")
            }
            .buttonStyle(.borderless)
            .help(effectiveDarkMode ? "라이트 모드로 전환" : "다크 모드로 전환")
            Button { settings.isPinned.toggle() } label: {
                Image(systemName: settings.isPinned ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .help(settings.isPinned ? "핀 해제" : "핀")
            Button { onRequestClose() } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .help("닫기")
        }
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
