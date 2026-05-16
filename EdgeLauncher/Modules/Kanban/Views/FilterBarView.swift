import SwiftUI

struct FilterBarView: View {
    @Bindable var viewModel: KanbanViewModel

    var body: some View {
        if let board = viewModel.activeBoard, !board.labels.isEmpty || !viewModel.filterLabelIds.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("필터").font(.appBody).foregroundStyle(.secondary)
                    ForEach(board.labels, id: \.id) { label in
                        let active = viewModel.filterLabelIds.contains(label.id)
                        Button {
                            viewModel.toggleFilterLabel(label.id)
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.fromHex(label.colorHex) ?? .accentColor)
                                    .frame(width: 16, height: 16)
                                Text(label.name)
                                    .font(.appBody)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill((Color.fromHex(label.colorHex) ?? .accentColor).opacity(active ? 0.45 : 0.15))
                            )
                            .foregroundStyle(active ? Color.primary : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    if !viewModel.filterLabelIds.isEmpty {
                        Button {
                            viewModel.clearFilters()
                        } label: {
                            Label("해제", systemImage: "xmark.circle.fill")
                                .font(.appBody)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .background(Color.primary.opacity(0.03))
        }
    }
}
