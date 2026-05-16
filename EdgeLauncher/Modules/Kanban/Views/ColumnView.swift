import SwiftUI
import UniformTypeIdentifiers

struct ColumnView: View {
    let board: KanbanBoard
    let column: KanbanColumn
    let width: CGFloat
    let height: CGFloat
    @Bindable var viewModel: KanbanViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var renameValue: String = ""
    @State private var isRenaming: Bool = false
    @State private var isEditingColor: Bool = false
    @State private var isDropTargeted: Bool = false
    @FocusState private var renameFocused: Bool

    var body: some View {
        let style = KanbanBoardStyle(isLight: colorScheme == .light)
        let accent = style.accent(from: column.colorHex)
        let hasCustomColor = column.colorHex != nil

        VStack(spacing: 0) {
            if style.isLight {
                Rectangle()
                    .fill(accent)
                    .frame(height: hasCustomColor ? 7 : 4)
            }
            header(style: style, accent: accent)
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .top) {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.startNewCard(in: column.id)
                        }
                    LazyVStack(spacing: 12) {
                        ForEach(Array(column.cards.enumerated()), id: \.element.id) { index, card in
                            DraggableCardRow(
                                boardId: board.id,
                                columnId: column.id,
                                index: index,
                                card: card,
                                labels: board.labels,
                                viewModel: viewModel
                            )
                        }
                        Color.clear.frame(height: 80)
                    }
                    .padding(12)
                }
                .frame(minHeight: max(0, height - 50))
            }
            .frame(maxHeight: .infinity)
            .background(style.columnBackground(accent: accent, hasCustomColor: hasCustomColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        style.columnStroke(accent: accent, hasCustomColor: hasCustomColor, isDropTargeted: isDropTargeted),
                        lineWidth: isDropTargeted || hasCustomColor ? 2 : 1
                    )
            )
            .shadow(color: style.isLight ? Color.black.opacity(0.04) : accent.opacity(hasCustomColor ? 0.24 : 0.05), radius: hasCustomColor ? 18 : 8, y: 8)
            .onDrop(of: [.kanbanCardRef, .plainText], isTargeted: $isDropTargeted) { providers in
                viewModel.handleDrop(providers: providers, toColumn: column.id, toIndex: column.cards.count)
            }
        }
        .frame(width: width, height: height)
        .sheet(isPresented: $isEditingColor) {
            KanbanColorEditorSheet(
                title: "\(column.name) 색상",
                initialColorHex: column.colorHex,
                onSave: { colorHex in
                    viewModel.store.setColumnColor(column.id, colorHex: colorHex)
                    isEditingColor = false
                },
                onCancel: { isEditingColor = false }
            )
        }
    }

    private func header(style: KanbanBoardStyle, accent: Color) -> some View {
        HStack {
            Circle()
                .fill(accent)
                .frame(width: 11, height: 11)
                .shadow(color: style.isLight ? .clear : accent.opacity(0.75), radius: 5)
            if isRenaming {
                TextField("이름", text: $renameValue, onCommit: commitRename)
                    .textFieldStyle(.roundedBorder)
                    .font(.appHeadingRegular)
                    .focused($renameFocused)
                    .frame(maxWidth: 240)
            } else {
                Text(column.name)
                    .font(.system(size: 20, weight: .bold))
                    .onTapGesture(count: 2, perform: beginRename)
            }
            Text("\(column.cards.count)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(style.isLight ? Color.secondary : Color.white.opacity(0.65))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(style.isLight ? Color.black.opacity(0.04) : Color.white.opacity(0.07)))
            Spacer()
            Button {
                viewModel.startNewCard(in: column.id)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
            }
            .buttonStyle(.borderless)
            Menu {
                Button("이름 변경", action: beginRename)
                Button {
                    isEditingColor = true
                } label: {
                    Label("색상 변경", systemImage: "paintpalette")
                }
                Divider()
                Button(role: .destructive) {
                    viewModel.deleteColumn(column.id)
                } label: {
                    Label("컬럼 삭제", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(style.headerFill)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(style.isLight ? style.divider : accent.opacity(column.colorHex == nil ? 0.28 : 0.45))
                .frame(height: 1)
        }
    }

    private func beginRename() {
        renameValue = column.name
        isRenaming = true
        renameFocused = true
    }

    private func commitRename() {
        let trimmed = renameValue.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            viewModel.renameColumn(column.id, name: trimmed)
        }
        isRenaming = false
    }
}

private struct DraggableCardRow: View {
    let boardId: UUID
    let columnId: UUID
    let index: Int
    let card: KanbanCard
    let labels: [KanbanLabel]
    @Bindable var viewModel: KanbanViewModel

    var body: some View {
        CardView(
            card: card,
            labels: labels,
            onTap: { viewModel.editCard(card) },
            onDelete: { viewModel.requestDelete(card) }
        )
        .onDrag {
            viewModel.dragProvider(ref: KanbanCardRef(
                cardId: card.id,
                boardId: boardId,
                sourceColumnId: columnId
            ))
        }
        .onDrop(of: [.kanbanCardRef, .plainText], isTargeted: nil) { providers in
            viewModel.handleDrop(providers: providers, toColumn: columnId, toIndex: index)
        }
    }
}
