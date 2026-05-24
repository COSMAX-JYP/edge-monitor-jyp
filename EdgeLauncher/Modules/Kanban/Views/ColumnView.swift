import SwiftUI
import UniformTypeIdentifiers

struct ColumnView: View {
    let board: KanbanBoard
    let column: KanbanColumn
    let width: CGFloat
    let height: CGFloat
    @Bindable var viewModel: KanbanViewModel
    /// SlidePad 처럼 호출 측이 컬럼 폭을 사용자 드래그로 갱신하고 싶을 때 주입.
    /// nil 이면 우측 가장자리 핸들이 표시되지 않는다 (기본 KanbanBoardView 동작 보존).
    /// - parameter translation: drag 시작점으로부터의 누적 translation.width.
    /// - parameter isEnded: false=onChanged, true=onEnded.
    var onWidthDrag: ((CGFloat, Bool) -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isSlidePadStyle) private var isSlidePadStyle
    @Environment(\.slidePadColorEditorPresenter) private var slidePadColorEditorPresenter

    @State private var renameValue: String = ""
    @State private var isRenaming: Bool = false
    @State private var isEditingColor: Bool = false
    @State private var isDropTargeted: Bool = false
    @FocusState private var renameFocused: Bool

    var body: some View {
        let style = KanbanBoardStyle(isLight: colorScheme == .light)
        let accent = style.accent(from: column.colorHex)
        let hasCustomColor = column.colorHex != nil

        let cornerRadius: CGFloat = isSlidePadStyle ? 6 : 12

        VStack(spacing: 0) {
            if style.isLight && !isSlidePadStyle {
                Rectangle()
                    .fill(accent)
                    .frame(height: hasCustomColor ? 7 : 4)
            }
            header(style: style, accent: accent)
            // 3:7 분할 — 위 30% 영역 + 가로 divider + 아래 70% 영역. GeometryReader 로
            // 정확한 비율 강제. ScrollView 가 자연 height 로 늘어나는 SwiftUI 동작 회피.
            GeometryReader { proxy in
                let totalH = proxy.size.height
                let dividerH: CGFloat = 1
                let usable = max(0, totalH - dividerH)
                let upperH = usable * 0.3
                let lowerH = usable * 0.7
                VStack(spacing: 0) {
                    zoneArea(
                        cards: column.cards.filter { $0.isUpper },
                        isUpper: true
                    )
                    .frame(height: upperH)
                    Divider().background(Color.primary.opacity(0.15))
                    zoneArea(
                        cards: column.cards.filter { !$0.isUpper },
                        isUpper: false
                    )
                    .frame(height: lowerH)
                }
            }
            .frame(maxHeight: .infinity)
            .background(
                isSlidePadStyle
                    ? (hasCustomColor
                        // 사용자 요청: 컬럼 색상에 따라 거의 반투명한 매우 옅은 톤.
                        ? AnyShapeStyle(accent.opacity(0.02))
                        : AnyShapeStyle(Color.white.opacity(0.03)))
                    : AnyShapeStyle(style.columnBackground(accent: accent, hasCustomColor: hasCustomColor))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        isSlidePadStyle
                            ? (hasCustomColor
                                ? AnyShapeStyle(accent)
                                : AnyShapeStyle(Color.white.opacity(isDropTargeted ? 0.2 : 0.06)))
                            : AnyShapeStyle(style.columnStroke(accent: accent, hasCustomColor: hasCustomColor, isDropTargeted: isDropTargeted)),
                        lineWidth: isSlidePadStyle
                            ? (hasCustomColor ? 2 : (isDropTargeted ? 1.5 : 0.5))
                            : (isDropTargeted || hasCustomColor ? 2 : 1)
                    )
            )
            .shadow(
                color: isSlidePadStyle
                    ? Color.clear
                    : (style.isLight ? Color.black.opacity(0.04) : accent.opacity(hasCustomColor ? 0.24 : 0.05)),
                radius: isSlidePadStyle ? 0 : (hasCustomColor ? 18 : 8),
                y: isSlidePadStyle ? 0 : 8
            )
            .onDrop(of: [.kanbanCardRef, .plainText], isTargeted: $isDropTargeted) { providers in
                viewModel.handleDrop(providers: providers, toColumn: column.id, toIndex: column.cards.count)
            }
        }
        .frame(width: width, height: height)
        .dismissiblePopup(isPresented: $isEditingColor) {
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

    /// 3:7 영역. 카드 목록 + 빈 영역 tap-to-add + drop target 시 outline 강조.
    @ViewBuilder
    private func zoneArea(cards: [KanbanCard], isUpper: Bool) -> some View {
        ZoneAreaView(
            cards: cards,
            isUpper: isUpper,
            board: board,
            column: column,
            viewModel: viewModel,
            isSlidePadStyle: isSlidePadStyle
        )
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
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.72)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    )
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: accent.opacity(0.45), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .help("새 카드 추가")
            Menu {
                Button("이름 변경", action: beginRename)
                Button {
                    if let presenter = slidePadColorEditorPresenter {
                        presenter(column.id, column.colorHex)
                    } else {
                        isEditingColor = true
                    }
                } label: {
                    Label("색상 변경", systemImage: "paintpalette")
                }
                Divider()
                Button {
                    viewModel.toggleShowHidden()
                } label: {
                    if viewModel.showHiddenCards {
                        Label("숨기기", systemImage: "eye.slash")
                    } else {
                        Label("숨김 표시 (\(viewModel.hiddenCardCount))", systemImage: "eye")
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
    let columnName: String
    let index: Int
    let card: KanbanCard
    let labels: [KanbanLabel]
    @Bindable var viewModel: KanbanViewModel

    var body: some View {
        let isExternal = viewModel.isReminderCard(card.id)
        let isHidden = viewModel.isHiddenCard(card.id)
        let showsHideAction = columnName.contains("완료")
        let hideAction: CardView.HideAction? = {
            guard showsHideAction else { return nil }
            if isHidden {
                return .unhide({ viewModel.unhideCard(card) })
            }
            return .hide({ viewModel.hideCard(card) })
        }()
        CardView(
            card: card,
            labels: labels,
            isExternal: isExternal,
            hideAction: hideAction,
            onTap: { viewModel.editCard(card) },
            onDelete: { viewModel.requestDelete(card) },
            onToggleZone: isExternal ? nil : { viewModel.toggleCardZone(card.id) }
        )
        .modifier(CardDragModifier(
            cardId: card.id,
            boardId: boardId,
            columnId: columnId,
            viewModel: viewModel
        ))
        .onDrop(of: [.kanbanCardRef, .plainText], isTargeted: nil) { providers in
            viewModel.handleDrop(providers: providers, toColumn: columnId, toIndex: index)
        }
    }
}

/// 모든 카드(로컬 + 미리알림) 를 드래그 가능하게 한다. 미리알림 카드는 드롭 시
/// KanbanViewModel.handleDrop 가 일반↔미리알림 변환을 처리한다.
private struct CardDragModifier: ViewModifier {
    let cardId: UUID
    let boardId: UUID
    let columnId: UUID
    let viewModel: KanbanViewModel

    func body(content: Content) -> some View {
        content.onDrag {
            viewModel.dragProvider(ref: KanbanCardRef(
                cardId: cardId,
                boardId: boardId,
                sourceColumnId: columnId
            ))
        }
    }
}

/// 위 30% / 아래 70% zone 각각의 wrapper. 카드 목록, tap-to-add, drop target outline.
private struct ZoneAreaView: View {
    let cards: [KanbanCard]
    let isUpper: Bool
    let board: KanbanBoard
    let column: KanbanColumn
    @Bindable var viewModel: KanbanViewModel
    let isSlidePadStyle: Bool

    @State private var isDropTargeted: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.startNewCard(in: column.id, isUpper: isUpper)
                    }
                VStack(spacing: isSlidePadStyle ? 4 : 12) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        DraggableCardRow(
                            boardId: board.id,
                            columnId: column.id,
                            columnName: column.name,
                            index: index,
                            card: card,
                            labels: board.labels,
                            viewModel: viewModel
                        )
                    }
                    Spacer(minLength: 0)
                }
                .padding(isSlidePadStyle ? 6 : 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.12), value: isDropTargeted)
        )
        .onDrop(of: [.kanbanCardRef, .plainText], isTargeted: $isDropTargeted) { providers in
            viewModel.handleDrop(
                providers: providers,
                toColumn: column.id,
                toIndex: cards.count,
                toUpper: isUpper
            )
        }
    }
}
