import SwiftUI

struct ButtonGridView: View {
    let page: StreamDeckPage
    @Bindable var viewModel: StreamDeckViewModel

    private let spacing: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let cellSize = computeCellSize(in: proxy.size)
            HStack(alignment: .top, spacing: spacing) {
                pageRail(cellSize: cellSize)
                    .frame(width: cellSize, height: gridHeight(cellSize: cellSize))

                Color.clear
                    .frame(width: cellSize, height: cellSize)
                    .accessibilityHidden(true)

                VStack(spacing: spacing) {
                    ForEach(0..<page.gridSize.rows, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<page.gridSize.cols, id: \.self) { col in
                                let pos = GridPosition(row: row, col: col)
                                slot(at: pos)
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func slot(at position: GridPosition) -> some View {
        if let button = page.button(at: position) {
            StreamDeckButtonView(
                button: button,
                isExecuting: viewModel.executingButtonId == button.id,
                isFlashing: viewModel.lastFiredFlashId == button.id,
                isEditing: viewModel.isEditing,
                onTap: { viewModel.tap(button) },
                onEdit: { viewModel.beginEditing(at: position) },
                onDelete: { viewModel.deleteButton(at: position) }
            )
        } else {
            EmptySlotView(isEditing: viewModel.isEditing) {
                viewModel.beginEditing(at: position)
            }
        }
    }

    private func pageRail(cellSize: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: spacing) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    pageButton(page: page, index: index)
                        .frame(width: cellSize, height: cellSize)
                }

                Button {
                    viewModel.startCreatePage()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: cellSize * 0.32, weight: .light))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                .foregroundStyle(.secondary.opacity(0.35))
                        )
                }
                .buttonStyle(.plain)
                .frame(width: cellSize, height: cellSize)
                .help("페이지 추가")
            }
        }
    }

    private func pageButton(page: StreamDeckPage, index: Int) -> some View {
        let isActive = page.id == viewModel.activePage?.id
        let color = Color.fromHex(page.colorHex) ?? .accentColor
        return Button {
            viewModel.selectPage(page.id)
        } label: {
            GeometryReader { proxy in
                let cell = min(proxy.size.width, proxy.size.height)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isActive ? color.opacity(0.22) : Color.primary.opacity(0.06))

                    Circle()
                        .fill(color)
                        .frame(width: cell * 0.1, height: cell * 0.1)
                        .padding(cell * 0.1)

                    VStack(spacing: cell * 0.06) {
                        Image(systemName: "rectangle.grid.1x2.fill")
                            .font(.system(size: cell * 0.32, weight: .semibold))
                            .foregroundStyle(isActive ? color : .secondary)

                        Text(page.name)
                            .font(.system(size: cell * 0.13, weight: isActive ? .semibold : .regular))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)

                        if index < 9 {
                            Text("⌘\(index + 1)")
                                .font(.system(size: cell * 0.11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(cell * 0.08)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isActive ? color : Color.clear, lineWidth: 2)
                )
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("이름 변경") { viewModel.startRenamePage(page) }
            if viewModel.pages.count > 1 {
                Button(role: .destructive) {
                    viewModel.requestDeletePage(page)
                } label: {
                    Label("페이지 삭제", systemImage: "trash")
                }
            }
        }
        .help(page.name)
    }

    private func gridHeight(cellSize: CGFloat) -> CGFloat {
        let rows = CGFloat(page.gridSize.rows)
        return cellSize * rows + spacing * max(rows - 1, 0)
    }

    private func computeCellSize(in size: CGSize) -> CGFloat {
        let cols = CGFloat(page.gridSize.cols + 2)
        let rows = CGFloat(page.gridSize.rows)
        let usableWidth = max(size.width - spacing * (cols + 1), 0)
        let usableHeight = max(size.height - spacing * (rows + 1), 0)
        let byWidth = usableWidth / cols
        let byHeight = usableHeight / rows
        return max(min(byWidth, byHeight), 96)
    }
}
