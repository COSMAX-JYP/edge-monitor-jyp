import SwiftUI

struct ActionStatsSheet: View {
    @Bindable var viewModel: StreamDeckViewModel
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Pad 액션 통계").font(.appTitle)
                Spacer()
                Button(role: .destructive) {
                    viewModel.resetStats()
                } label: {
                    Label("초기화", systemImage: "trash").font(.appBody)
                }
                Button("닫기", action: onDismiss)
                    .font(.appBody)
                    .keyboardShortcut(.escape, modifiers: [])
            }

            summaryCards

            Divider()

            Text("자주 사용한 버튼").font(.appHeading)

            ScrollView {
                LazyVStack(spacing: 8) {
                    let entries = viewModel.stats.topUsed(limit: 50)
                    if entries.isEmpty {
                        Text("아직 누른 버튼이 없습니다")
                            .font(.appBody)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 32)
                    }
                    ForEach(entries, id: \.buttonId) { entry in
                        statsRow(entry: entry)
                    }
                }
            }
        }
        .padding(24)
        .appSheetFrame(width: 0.5...0.8, height: 0.55...0.85)
    }

    private var summaryCards: some View {
        let allEntries = Array(viewModel.stats.data.entries.values)
        let totalTaps = allEntries.reduce(0) { $0 + $1.tapCount }
        let totalSuccess = allEntries.reduce(0) { $0 + $1.successCount }
        let totalErrors = allEntries.reduce(0) { $0 + $1.errorCount }
        let avgRate = totalTaps > 0 ? Double(totalSuccess) / Double(totalTaps) : 0

        return HStack(spacing: 12) {
            SummaryCard(label: "총 탭", value: "\(totalTaps)", color: .accentColor)
            SummaryCard(label: "성공", value: "\(totalSuccess)", color: .green)
            SummaryCard(label: "실패", value: "\(totalErrors)", color: .red)
            SummaryCard(label: "성공률", value: String(format: "%.0f%%", avgRate * 100), color: .blue)
        }
    }

    private func statsRow(entry: ActionStatsEntry) -> some View {
        let button = viewModel.buttonForStats(entry.buttonId)
        let page = viewModel.pageForButton(entry.buttonId)
        return HStack(spacing: 14) {
            if let button {
                Image(systemName: button.icon.type == .sfSymbol ? button.icon.value.replacingOccurrences(of: "", with: "square") : "square.dashed")
                    .font(.appHeading)
                    .foregroundStyle(Color.fromHex(button.foregroundHex) ?? .primary)
                    .frame(width: 32)
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .font(.appHeading)
                    .foregroundStyle(.secondary)
                    .frame(width: 32)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(button?.label.isEmpty == false ? button!.label : (button?.action.kindLabel ?? "(삭제된 버튼)"))
                    .font(.appCalloutBold)
                HStack(spacing: 10) {
                    if let page {
                        Text(page.name).font(.appFootnote).foregroundStyle(.secondary)
                    }
                    if let last = entry.lastTappedAt {
                        Text("마지막 \(relativeDate(last))").font(.appFootnote).foregroundStyle(.secondary)
                    }
                    if entry.successCount > 0 {
                        Text(String(format: "평균 %.2fs", entry.averageDuration))
                            .font(.appFootnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(entry.tapCount)").font(.appTitleMono)
                HStack(spacing: 8) {
                    Text("✓ \(entry.successCount)").font(.appFootnote).foregroundStyle(.green)
                    if entry.errorCount > 0 {
                        Text("✗ \(entry.errorCount)").font(.appFootnote).foregroundStyle(.red)
                    }
                }
            }
            if let last = entry.lastError, entry.errorCount > 0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.appBody)
                    .foregroundStyle(.orange)
                    .help(last)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ko_KR")
        return f.localizedString(for: date, relativeTo: Date())
    }
}

private struct SummaryCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.appFootnote).foregroundStyle(.secondary)
            Text(value).font(.appTitleBold).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}
