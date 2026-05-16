import SwiftUI

struct KanbanBoardView: View {
    @Bindable var viewModel: KanbanViewModel
    @Environment(\.colorScheme) private var colorScheme

    private let columnSpacing: CGFloat = 12
    private let minColumnWidth: CGFloat = 420
    private let maxColumnWidth: CGFloat = 560

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
        .sheet(item: $viewModel.editingCard) { card in
            CardEditorSheet(
                initial: card,
                labels: viewModel.activeBoard?.labels ?? [],
                isNew: viewModel.editingTargetColumnId != nil,
                onSave: viewModel.saveEditing,
                onCancel: viewModel.cancelEditing
            )
        }
        .sheet(item: $viewModel.editingBoard) { board in
            BoardEditorSheet(
                initial: board,
                isNew: viewModel.isCreatingBoard,
                onSave: viewModel.saveBoardEditing,
                onCancel: viewModel.cancelBoardEditing
            )
        }
        .sheet(isPresented: $viewModel.isManagingLabels) {
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
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: columnSpacing) {
                        ForEach(columns, id: \.id) { column in
                            ColumnView(
                                board: board,
                                column: column,
                                width: columnWidth(forVisible: max(columns.count, 1), in: width - detailWidth()),
                                height: height,
                                viewModel: viewModel
                            )
                        }
                        AddColumnTile(width: columnWidth(forVisible: max(columns.count, 1), in: width - detailWidth())) {
                            beginAddColumn()
                        }
                        .frame(height: height)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .frame(minWidth: width - detailWidth(), minHeight: height, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
                if let detailCard = viewModel.detailCard {
                    CardDetailPanel(
                        card: detailCard,
                        labels: board.labels,
                        viewModel: viewModel,
                        onEdit: { viewModel.editCard(detailCard) },
                        onDelete: { viewModel.requestDelete(detailCard) },
                        onDismiss: { viewModel.dismissDetail() }
                    )
                }
            }
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

    private func detailWidth() -> CGFloat {
        viewModel.detailCard != nil ? 360 : 0
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
