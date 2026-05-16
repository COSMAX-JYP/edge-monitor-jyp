import SwiftUI

struct ColumnView: View {
    let board: KanbanBoard
    let column: KanbanColumn
    let width: CGFloat
    let height: CGFloat
    @Bindable var viewModel: KanbanViewModel

    @State private var renameValue: String = ""
    @State private var isRenaming: Bool = false
    @FocusState private var renameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
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
                            CardView(
                                card: card,
                                labels: board.labels,
                                onTap: { viewModel.editCard(card) },
                                onDelete: { viewModel.requestDelete(card) }
                            )
                            .draggable(KanbanCardRef(
                                cardId: card.id,
                                boardId: board.id,
                                sourceColumnId: column.id
                            ))
                            .dropDestination(for: KanbanCardRef.self) { items, _ in
                                guard let ref = items.first else { return false }
                                return viewModel.handleDrop(ref: ref, toColumn: column.id, toIndex: index)
                            }
                        }
                        Color.clear.frame(height: 80)
                    }
                    .padding(10)
                }
                .frame(minHeight: max(0, height - 50))
            }
            .frame(maxHeight: .infinity)
            .background(columnBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .dropDestination(for: KanbanCardRef.self) { items, _ in
                guard let ref = items.first else { return false }
                return viewModel.handleDrop(ref: ref, toColumn: column.id, toIndex: column.cards.count)
            }
        }
        .frame(width: width, height: height)
    }

    private var header: some View {
        HStack {
            if let hex = column.colorHex, let color = Color.fromHex(hex) {
                Circle().fill(color).frame(width: 16, height: 16)
            }
            if isRenaming {
                TextField("이름", text: $renameValue, onCommit: commitRename)
                    .textFieldStyle(.roundedBorder)
                    .font(.appHeadingRegular)
                    .focused($renameFocused)
                    .frame(maxWidth: 240)
            } else {
                Text(column.name)
                    .font(.appTitle)
                    .onTapGesture(count: 2, perform: beginRename)
            }
            Text("\(column.cards.count)")
                .font(.appBody)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
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
                Menu("색상") {
                    Button("기본") { viewModel.store.setColumnColor(column.id, colorHex: nil) }
                    ForEach(["#4A90E2", "#7ED321", "#F5A623", "#E94B3C", "#BD10E0"], id: \.self) { hex in
                        Button {
                            viewModel.store.setColumnColor(column.id, colorHex: hex)
                        } label: {
                            Label("", systemImage: "circle.fill")
                                .foregroundStyle(Color.fromHex(hex) ?? .accentColor)
                            Text(hex)
                        }
                    }
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
        .padding(.vertical, 10)
    }

    private var columnBackground: Color {
        if let hex = column.colorHex, let color = Color.fromHex(hex) {
            return color.opacity(0.22)
        }
        return Color.primary.opacity(0.04)
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
