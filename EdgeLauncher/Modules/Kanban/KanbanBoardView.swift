import SwiftUI

/// SlidePad 전용 톤(Compact Dense — outline 제거, 좁은 spacing) 분기를 위한 환경 키.
/// 메인 윈도우 칸반은 false(기본) → 기존 디자인 보존, SlidePad 안만 true.
private struct IsSlidePadStyleKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isSlidePadStyle: Bool {
        get { self[IsSlidePadStyleKey.self] }
        set { self[IsSlidePadStyleKey.self] = newValue }
    }
}

struct KanbanBoardView: View {
    @Bindable var viewModel: KanbanViewModel
    /// 호출 측에서 override 가능 — SlidePad 처럼 좁은 컨테이너에서는 더 작은 값 사용.
    var minColumnWidth: CGFloat = 420
    var maxColumnWidth: CGFloat = 560
    /// 컬럼 우측 가장자리 드래그로 컬럼 폭을 사용자 조절 가능. nil 이면 핸들 미표시.
    /// translation 은 drag 시작점으로부터의 누적 width, isEnded 는 onEnded 신호.
    /// 어느 컬럼의 핸들을 드래그하는지 column.id 를 함께 전달한다.
    var onColumnWidthDrag: ((UUID, CGFloat, Bool) -> Void)? = nil
    /// 컬럼별 폭 override. nil 이면 자동 균등 분할 (기존 동작).
    var columnWidthOverride: ((UUID) -> CGFloat?)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isSlidePadStyle) private var isSlidePadStyle

    private var columnSpacing: CGFloat { isSlidePadStyle ? 4 : 12 }

    @State private var newColumnName: String = ""
    @State private var isAddingColumn: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            BoardHeaderView(viewModel: viewModel, onAddColumn: beginAddColumn)
            Divider()
            FilterBarView(viewModel: viewModel)
            GeometryReader { proxy in
                content(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .background(style.boardBackground)
        .dismissiblePopup(item: $viewModel.editingCard, onDismiss: viewModel.cancelEditing) { card in
            CardEditorSheet(
                initial: card,
                labels: viewModel.activeBoard?.labels ?? [],
                isNew: viewModel.editingTargetColumnId != nil,
                onSave: viewModel.saveEditing,
                onCancel: viewModel.cancelEditing
            )
        }
        .dismissiblePopup(item: $viewModel.detailCard, onDismiss: viewModel.dismissDetail) { card in
            CardDetailPanel(
                card: card,
                labels: viewModel.activeBoard?.labels ?? [],
                viewModel: viewModel,
                onEdit: { viewModel.editCard(card) },
                onDelete: { viewModel.requestDelete(card) },
                onDismiss: viewModel.dismissDetail
            )
        }
        .dismissiblePopup(item: $viewModel.editingBoard, onDismiss: viewModel.cancelBoardEditing) { board in
            BoardEditorSheet(
                initial: board,
                isNew: viewModel.isCreatingBoard,
                onSave: viewModel.saveBoardEditing,
                onCancel: viewModel.cancelBoardEditing
            )
        }
        .dismissiblePopup(isPresented: $viewModel.isManagingLabels, onDismiss: viewModel.closeLabelManager) {
            LabelManagerSheet(
                labels: viewModel.activeBoard?.labels ?? [],
                onAdd: viewModel.addLabel,
                onUpdate: viewModel.updateLabel,
                onDelete: viewModel.deleteLabel,
                onDismiss: viewModel.closeLabelManager
            )
        }
        .alert(item: $viewModel.pendingDeleteCard) { card in
            Alert(
                title: Text("카드를 삭제할까요?"),
                message: Text(card.title.isEmpty ? "(제목 없음)" : card.title),
                primaryButton: .destructive(Text("삭제"), action: viewModel.confirmDelete),
                secondaryButton: .cancel(Text("취소"), action: viewModel.cancelDelete)
            )
        }
        .alert("보드를 삭제할까요?", isPresented: pendingDeleteBoardBinding) {
            Button("취소", role: .cancel, action: viewModel.cancelDeleteBoard)
            Button("삭제", role: .destructive, action: viewModel.confirmDeleteBoard)
        } message: {
            Text("이 작업은 되돌릴 수 없습니다.")
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.lastUndoToast {
                HStack(spacing: 12) {
                    Text(toast).font(.appCallout)
                    if viewModel.canUndo {
                        Button("실행 취소") { viewModel.undoLastDelete() }
                            .font(.appBody)
                            .keyboardShortcut("z", modifiers: .command)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 24)
            }
        }
        .alert("새 컬럼 이름", isPresented: $isAddingColumn) {
            TextField("이름", text: $newColumnName)
            Button("취소", role: .cancel) {
                newColumnName = ""
            }
            Button("추가") {
                commitAddColumn()
            }
        } message: {
            Text("빈 보드 공간에 추가할 컬럼 이름을 입력하세요.")
        }
    }

    private var style: KanbanBoardStyle {
        KanbanBoardStyle(isLight: colorScheme == .light)
    }

    private var pendingDeleteBoardBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingDeleteBoardId != nil },
            set: { if !$0 { viewModel.cancelDeleteBoard() } }
        )
    }

    @ViewBuilder
    private func content(width: CGFloat, height: CGFloat) -> some View {
        let columns = viewModel.visibleColumns
        if let board = viewModel.activeBoard, !columns.isEmpty {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: columnSpacing) {
                    ForEach(columns, id: \.id) { column in
                        let colWidth = columnWidthOverride?(column.id) ?? columnWidth(forVisible: max(columns.count, 1), in: width)
                        ColumnView(
                            board: board,
                            column: column,
                            width: colWidth,
                            height: height,
                            viewModel: viewModel,
                            onWidthDrag: nil
                        )
                        if let onColumnWidthDrag {
                            // Codex 권고: overlay 가 아니라 sibling 으로 둬야 horizontal/vertical
                            // ScrollView 가 drag 를 가로채지 않는다. ColumnView 의 onDrop 모디파이어
                            // 영역 바깥에 위치.
                            KanbanColumnResizeHandle(height: height) { dx, isEnded in
                                onColumnWidthDrag(column.id, dx, isEnded)
                            }
                        }
                    }
                    AddColumnTile(width: columnWidth(forVisible: max(columns.count, 1), in: width)) {
                        beginAddColumn()
                    }
                    .frame(height: height)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(minWidth: width, minHeight: height, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 14) {
                Image(systemName: "rectangle.split.3x1")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("보드가 비어 있습니다")
                    .font(.appTitle)
                Text("Cmd+N 또는 컬럼의 + 버튼으로 카드를 추가하세요.")
                    .font(.appBody)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                beginAddColumn()
            }
        }
    }

    private func columnWidth(forVisible count: Int, in width: CGFloat) -> CGFloat {
        let n = max(count, 1)
        let totalSpacing = columnSpacing * CGFloat(n + 1)
        let raw = (width - totalSpacing) / CGFloat(n)
        return max(minColumnWidth, min(raw, maxColumnWidth))
    }

    private func beginAddColumn() {
        newColumnName = ""
        isAddingColumn = true
    }

    private func commitAddColumn() {
        let trimmed = newColumnName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            viewModel.addColumn(name: trimmed)
        }
        newColumnName = ""
    }
}

/// 컬럼 사이에 놓이는 가는 드래그 핸들. macOS 26 beta 에서 NSScrollView 의 native pan
/// 이 SwiftUI .gesture 를 일관되게 가로채는 문제(codex 진단)로, AppKit NSView 로 직접
/// mouseDown/Dragged/Up 처리한다. NSResponder chain 에서 자식 view 가 먼저 받으므로
/// ScrollView 와 충돌 없음.
struct KanbanColumnResizeHandle: View {
    let height: CGFloat
    let onWidthDrag: (CGFloat, Bool) -> Void

    var body: some View {
        ColumnResizeHandleRepresentable(onWidthDrag: onWidthDrag)
            .frame(width: 12, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary.opacity(0.18))
                    .frame(width: 3, height: 32)
            )
            .allowsHitTesting(true)
    }
}

private struct ColumnResizeHandleRepresentable: NSViewRepresentable {
    let onWidthDrag: (CGFloat, Bool) -> Void

    func makeNSView(context: Context) -> ColumnResizeHandleNSView {
        let v = ColumnResizeHandleNSView()
        v.onWidthDrag = onWidthDrag
        return v
    }

    func updateNSView(_ nsView: ColumnResizeHandleNSView, context: Context) {
        nsView.onWidthDrag = onWidthDrag
    }
}

final class ColumnResizeHandleNSView: NSView {
    var onWidthDrag: ((CGFloat, Bool) -> Void)?
    private var startScreenX: CGFloat = 0
    private var monitor: Any?
    private var isDragging = false

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { installMonitor() } else { removeMonitor() }
    }

    deinit { removeMonitor() }

    /// NSEvent.localMonitor 으로 NSPanel 안 모든 mouse event 를 SwiftUI tree 와 무관하게
    /// 가로챈다. ScrollView native pan / scaleEffect hit-test / .onDrop 어느 것도 우리보다
    /// 먼저 받지 못한다.
    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self else { return event }
            guard let win = self.window, event.window === win else { return event }
            switch event.type {
            case .leftMouseDown:
                if self.containsEvent(event) {
                    self.isDragging = true
                    self.startScreenX = self.screenX(for: event)
                    return nil
                }
                return event
            case .leftMouseDragged:
                if self.isDragging {
                    let dx = self.screenX(for: event) - self.startScreenX
                    self.onWidthDrag?(dx, false)
                    return nil
                }
                return event
            case .leftMouseUp:
                if self.isDragging {
                    let dx = self.screenX(for: event) - self.startScreenX
                    self.onWidthDrag?(dx, true)
                    self.isDragging = false
                    return nil
                }
                return event
            default: return event
            }
        }
    }

    private func removeMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    /// event 좌표가 self 의 윈도우 좌표 frame 안인지.
    private func containsEvent(_ event: NSEvent) -> Bool {
        let myFrameInWindow = self.convert(self.bounds, to: nil)
        return myFrameInWindow.contains(event.locationInWindow)
    }

    private func screenX(for event: NSEvent) -> CGFloat {
        guard let win = window else { return event.locationInWindow.x }
        return win.convertPoint(toScreen: event.locationInWindow).x
    }
}

private struct AddColumnTile: View {
    let width: CGFloat
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 28, weight: .semibold))
                Text("컬럼 추가")
                    .font(.appHeading)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                    .foregroundStyle(Color.primary.opacity(0.16))
            )
        }
        .buttonStyle(.plain)
        .frame(width: width)
        .help("빈 공간에 새 컬럼 추가")
    }
}
