import SwiftUI

struct BoardHeaderView: View {
    @Bindable var viewModel: KanbanViewModel
    var onAddColumn: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            BoardPickerView(viewModel: viewModel)

            if let column = viewModel.activeBoard?.columns.first {
                Button {
                    viewModel.startNewCard(in: column.id)
                } label: {
                    Label("새 카드", systemImage: "plus")
                        .font(.appBodyBold)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            Menu {
                Button("라벨 관리") {
                    viewModel.openLabelManager()
                }
                Button("컬럼 추가") {
                    onAddColumn()
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.appBody)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.appCallout)
                    .foregroundStyle(.secondary)
                TextField("카드 검색", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.appHeadingRegular)
                    .frame(width: 260)
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.appCallout)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
