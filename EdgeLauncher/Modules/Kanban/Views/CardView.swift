import SwiftUI

struct CardView: View {
    let card: KanbanCard
    let labels: [KanbanLabel]
    var onTap: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(stripeLabels.prefix(4), id: \.id) { label in
                    Capsule()
                        .fill(Color.fromHex(label.colorHex) ?? .accentColor)
                        .frame(width: 36, height: 8)
                        .help(label.name)
                }
                Spacer()
            }
            Text(card.title.isEmpty ? "(제목 없음)" : card.title)
                .font(.appHeading)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let due = card.dueDate {
                Label(dueLabel(due), systemImage: "calendar")
                    .font(.appCallout)
                    .foregroundStyle(dueColor(due))
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button("편집") { onTap() }
            Divider()
            Button("삭제", role: .destructive) { onDelete() }
        }
    }

    private var stripeLabels: [KanbanLabel] {
        labels.filter { card.labelIds.contains($0.id) }
    }

    private var cardBackground: Color {
        if let hex = card.colorHex, let parsed = Color.fromHex(hex) {
            return parsed.opacity(0.15)
        }
        return Color.primary.opacity(0.04)
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
