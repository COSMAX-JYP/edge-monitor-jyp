import SwiftUI

struct KanbanSlidePanelView: View {
    @Bindable var viewModel: KanbanViewModel
    @Bindable var settings: KanbanSlidePanelSettings
    var onRequestClose: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView(.horizontal, showsIndicators: true) {
                KanbanBoardView(viewModel: viewModel)
                    .frame(minWidth: 1200, alignment: .leading)
            }
            .background(.ultraThinMaterial)
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 8) {
            BoardPickerView(viewModel: viewModel)
            Spacer()
            Button { settings.isPinned.toggle() } label: {
                Image(systemName: settings.isPinned ? "pin.fill" : "pin")
            }
            .help(settings.isPinned ? "핀 해제" : "핀")
            Button { onRequestClose() } label: { Image(systemName: "xmark") }
                .help("닫기")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
