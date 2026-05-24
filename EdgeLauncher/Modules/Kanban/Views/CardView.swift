import SwiftUI

struct CardView: View {
    let card: KanbanCard
    let labels: [KanbanLabel]
    var isExternal: Bool = false
    var hideAction: HideAction? = nil
    var onTap: () -> Void
    var onDelete: () -> Void
    var onToggleZone: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme

    enum HideAction {
        case hide(() -> Void)
        case unhide(() -> Void)
    }

    var body: some View {
        let style = KanbanBoardStyle(isLight: colorScheme == .light)
        let accent = cardAccent(style: style)

        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 4) {
                ForEach(stripeLabels.prefix(4), id: \.id) { label in
                    Capsule()
                        .fill(Color.fromHex(label.colorHex) ?? .accentColor)
                        .frame(width: 36, height: 8)
                        .help(label.name)
                }
                Spacer()
                if isExternal {
                    Label("미리알림", systemImage: "checklist")
                        .labelStyle(.iconOnly)
                        .font(.appFootnote)
                        .foregroundStyle(.secondary)
                        .help("macOS 미리알림에서 동기화됨")
                }
                if let action = hideAction {
                    hideButton(action: action)
                }
            }
            Text(card.title.isEmpty ? "(제목 없음)" : card.title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(style.isLight ? Color(red: 0.10, green: 0.13, blue: 0.18) : Color.white.opacity(0.96))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let due = card.dueDate {
                Label(dueLabel(due), systemImage: "calendar")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.red)
            }
            if !card.assignee.isEmpty {
                Label(card.assignee, systemImage: "person.crop.circle")
                    .font(.appCallout)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                if !card.checklist.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: card.hasCompletedChecklist ? "checkmark.circle.fill" : "checklist")
                            .foregroundStyle(card.hasCompletedChecklist ? Color.green : .secondary)
                        Text("\(card.checklistDone)/\(card.checklist.count)")
                            .font(.appFootnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if !card.attachments.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "paperclip")
                            .foregroundStyle(.secondary)
                        Text("\(card.attachments.count)")
                            .font(.appFootnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if !card.checklist.isEmpty {
                ProgressView(value: card.progress)
                    .progressViewStyle(.linear)
                    .tint(card.hasCompletedChecklist ? .green : .accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackground(style: style, accent: accent))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(cardStroke(style: style, accent: accent), lineWidth: style.isLight ? 1 : 1.5)
        )
        .shadow(color: style.isLight ? Color.black.opacity(0.05) : accent.opacity(card.colorHex == nil ? 0.08 : 0.20), radius: style.isLight ? 14 : 18, y: 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button("편집") { onTap() }
            if let onToggleZone {
                Button(card.isUpper ? "아래 영역으로 이동" : "위 영역으로 이동") {
                    onToggleZone()
                }
            }
            Divider()
            Button("삭제", role: .destructive) { onDelete() }
        }
    }

    private var stripeLabels: [KanbanLabel] {
        labels.filter { card.labelIds.contains($0.id) }
    }

    @ViewBuilder
    private func hideButton(action: HideAction) -> some View {
        switch action {
        case .hide(let perform):
            Button {
                perform()
            } label: {
                Image(systemName: "eye.slash")
                    .font(.appCallout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("이 카드 숨기기")
        case .unhide(let perform):
            Button {
                perform()
            } label: {
                Image(systemName: "eye")
                    .font(.appCallout)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("숨김 해제")
        }
    }

    private func cardAccent(style: KanbanBoardStyle) -> Color {
        if let hex = card.colorHex, let parsed = Color.fromHex(hex) {
            return parsed
        }
        return style.defaultAccent
    }

    private func cardBackground(style: KanbanBoardStyle, accent: Color) -> Color {
        if card.colorHex != nil {
            return style.isLight ? accent.opacity(0.08) : accent.opacity(0.12)
        }
        return style.cardFill
    }

    private func cardStroke(style: KanbanBoardStyle, accent: Color) -> Color {
        if card.colorHex != nil {
            return accent.opacity(style.isLight ? 0.35 : 0.58)
        }
        return style.cardLine
    }

    private func dueLabel(_ due: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: due)
    }

    private func dueColor(_ due: Date) -> Color {
        let now = Date()
        if due < now { return .red }
        if Calendar.current.isDateInToday(due) { return .orange }
        if Calendar.current.isDate(due, inSameDayAs: now.addingTimeInterval(86400)) { return .yellow }
        return .secondary
    }
}
