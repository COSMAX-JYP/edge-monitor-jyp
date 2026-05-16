import SwiftUI

struct DateHeaderView: View {
    @Bindable var viewModel: TimelineViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.goToPrevious()
            } label: {
                Image(systemName: "chevron.left").font(.appBody)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.leftArrow, modifiers: .command)

            Text(dateLabel)
                .font(.appTitleMono)
                .frame(minWidth: 260)
                .multilineTextAlignment(.center)

            Button {
                viewModel.goToNext()
            } label: {
                Image(systemName: "chevron.right").font(.appBody)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.rightArrow, modifiers: .command)

            Button("오늘") {
                viewModel.goToToday()
            }
            .font(.appBody)
            .keyboardShortcut("t", modifiers: .command)

            Button {
                viewModel.startNewEvent()
            } label: {
                Label("새 일정", systemImage: "plus").font(.appBodyBold)
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(!viewModel.permissionState.isUsable || viewModel.calendars.isEmpty)

            Spacer()

            if viewModel.isLoading {
                ProgressView().controlSize(.regular)
            }

            Button {
                Task { await viewModel.reload() }
            } label: {
                Image(systemName: "arrow.clockwise").font(.appBody)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy-MM-dd (E)"
        return f.string(from: viewModel.currentDay)
    }
}
