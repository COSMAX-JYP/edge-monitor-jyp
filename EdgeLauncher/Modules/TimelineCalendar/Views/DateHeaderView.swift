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
                .frame(minWidth: 220)
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

            viewModePicker

            Button {
                viewModel.startNewEvent()
            } label: {
                Label("새 일정", systemImage: "plus").font(.appBodyBold)
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(!viewModel.permissionState.isUsable || viewModel.calendars.isEmpty)

            Spacer()

            outlookSection

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

    private var viewModePicker: some View {
        Picker("View", selection: Binding(
            get: { viewModel.viewMode },
            set: { viewModel.setViewMode($0) }
        )) {
            ForEach(TimelineViewMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        switch viewModel.viewMode {
        case .day:
            f.dateFormat = "yyyy-MM-dd (E)"
            return f.string(from: viewModel.currentDay)
        case .week:
            let cal = Calendar.current
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: viewModel.currentDay)?.start,
                  let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) else {
                f.dateFormat = "yyyy-MM-dd"
                return f.string(from: viewModel.currentDay)
            }
            f.dateFormat = "yyyy-MM-dd"
            return "\(f.string(from: weekStart)) ~ \(f.string(from: weekEnd))"
        case .month:
            f.dateFormat = "yyyy년 M월"
            return f.string(from: viewModel.currentDay)
        }
    }

    @ViewBuilder
    private var outlookSection: some View {
        if viewModel.msalAuth != nil {
            HStack(spacing: 8) {
                if viewModel.outlookSignedIn {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text(viewModel.outlookUsername ?? "Outlook")
                            .font(.appFootnote)
                            .lineLimit(1)
                    }
                    Button {
                        Task { await viewModel.signOutOutlook() }
                    } label: {
                        Label("Outlook 로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.appFootnote)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button {
                        Task { await viewModel.signInOutlook() }
                    } label: {
                        Label("Outlook 로그인", systemImage: "person.crop.circle.badge.plus")
                            .font(.appFootnoteBold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
        }
    }
}
