import SwiftUI

struct BoardPickerView: View {
    @Bindable var viewModel: KanbanViewModel

    var body: some View {
        Menu {
            ForEach(viewModel.boards, id: \.id) { board in
                Button {
                    viewModel.selectBoard(board.id)
                } label: {
                    HStack {
                        if let color = Color.fromHex(board.colorHex) {
                            Circle().fill(color).frame(width: 8, height: 8)
                        }
                        Text(board.name)
                        if board.id == viewModel.activeBoard?.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button {
                viewModel.startCreateBoard()
            } label: {
                Label("새 보드", systemImage: "plus")
            }
            if let active = viewModel.activeBoard {
                Button {
                    viewModel.startEditBoard(active)
                } label: {
                    Label("보드 이름 변경", systemImage: "pencil")
                }
                if viewModel.boards.count > 1 {
                    Button(role: .destructive) {
                        viewModel.requestDeleteBoard(active.id)
                    } label: {
                        Label("보드 삭제", systemImage: "trash")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let active = viewModel.activeBoard, let color = Color.fromHex(active.colorHex) {
                    Circle().fill(color).frame(width: 16, height: 16)
                }
                Text(viewModel.activeBoard?.name ?? "보드 없음")
                    .font(.appTitle)
                Image(systemName: "chevron.down")
                    .font(.appFootnoteBold)
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
