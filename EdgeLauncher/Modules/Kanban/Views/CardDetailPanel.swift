import SwiftUI
import UniformTypeIdentifiers

struct CardDetailPanel: View {
    let card: KanbanCard
    let labels: [KanbanLabel]
    @Bindable var viewModel: KanbanViewModel
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onDismiss: () -> Void

    @State private var newChecklistText: String = ""
    @State private var attachmentDropTargeted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(card.title.isEmpty ? "(제목 없음)" : card.title)
                    .font(.appTitle)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                Spacer()
                Button("편집", action: onEdit)
                    .kanbanDialogSecondaryButton()
                Button("삭제", role: .destructive, action: onDelete)
                    .kanbanDialogSecondaryButton()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.appBody)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.escape, modifiers: [])
            }
            if !cardLabels.isEmpty {
                FlowChips(labels: cardLabels)
            }
            if let due = card.dueDate {
                Label(dueLabel(due), systemImage: "calendar")
                    .font(.appCallout)
                    .foregroundStyle(.secondary)
            }
            if !card.assignee.isEmpty {
                Label(card.assignee, systemImage: "person.crop.circle")
                    .font(.appCallout)
                    .foregroundStyle(.secondary)
            }
            if !card.notes.isEmpty {
                Divider()
                Text("노트").font(.appFootnote).foregroundStyle(.secondary)
                ScrollView {
                    Text(card.notes)
                        .font(.appBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
            }
            checklistSection
            attachmentSection
            Spacer(minLength: 0)
        }
        .padding(24)
        .appSheetFrame(width: 0.35...0.56, height: 0.5...0.85)
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Text("체크리스트").font(.appFootnote).foregroundStyle(.secondary)
                Spacer()
                if !card.checklist.isEmpty {
                    Text("\(card.checklistDone)/\(card.checklist.count)")
                        .font(.appFootnote)
                        .foregroundStyle(.secondary)
                }
            }
            if !card.checklist.isEmpty {
                ProgressView(value: card.progress)
                    .tint(card.hasCompletedChecklist ? .green : .accentColor)
                ForEach(card.checklist, id: \.id) { item in
                    HStack(spacing: 8) {
                        Button {
                            viewModel.toggleChecklistItem(item.id, in: card.id)
                        } label: {
                            Image(systemName: item.done ? "checkmark.square.fill" : "square")
                                .font(.appCallout)
                                .foregroundStyle(item.done ? Color.green : .secondary)
                        }
                        .buttonStyle(.plain)
                        Text(item.text)
                            .font(.appCallout)
                            .strikethrough(item.done, color: .secondary)
                            .foregroundStyle(item.done ? .secondary : .primary)
                        Spacer()
                        Button {
                            viewModel.removeChecklistItem(item.id, in: card.id)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.appCallout)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            HStack(spacing: 6) {
                TextField("새 항목", text: $newChecklistText, onCommit: addChecklistItem)
                    .textFieldStyle(.roundedBorder)
                    .font(.appCallout)
                Button {
                    addChecklistItem()
                } label: {
                    Image(systemName: "plus")
                        .font(.appBody)
                }
                .buttonStyle(.borderless)
                .disabled(newChecklistText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var attachmentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Text("첨부").font(.appFootnote).foregroundStyle(.secondary)
                Spacer()
                Text("\(card.attachments.count)")
                    .font(.appFootnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(card.attachments, id: \.id) { att in
                HStack(spacing: 8) {
                    Image(systemName: att.isImage ? "photo" : "doc")
                        .font(.appCallout)
                        .foregroundStyle(att.exists ? Color.accentColor : .secondary)
                    Button {
                        viewModel.revealAttachment(att)
                    } label: {
                        Text(att.displayName)
                            .lineLimit(1)
                            .font(.appCallout)
                    }
                    .buttonStyle(.plain)
                    if !att.exists {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .help("파일을 찾을 수 없습니다")
                    }
                    Spacer()
                    Button {
                        viewModel.removeAttachment(att.id, from: card.id)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            attachmentDropZone
        }
    }

    private var attachmentDropZone: some View {
        VStack(spacing: 4) {
            Image(systemName: "tray.and.arrow.down")
                .font(.appBody)
                .foregroundStyle(.secondary)
            Text("파일을 드래그하거나 클릭하여 추가")
                .font(.appFootnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(attachmentDropTargeted ? Color.accentColor : .secondary.opacity(0.5))
        )
        .contentShape(Rectangle())
        .onTapGesture { pickFiles() }
        .onDrop(of: [.fileURL], isTargeted: $attachmentDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var paths: [String] = []
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.isFileURL { paths.append(url.path) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            Task { @MainActor in
                viewModel.addAttachments(paths: paths, to: card.id)
            }
        }
        return true
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            viewModel.addAttachments(paths: panel.urls.map(\.path), to: card.id)
        }
    }

    private func addChecklistItem() {
        let trimmed = newChecklistText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.addChecklistItem(text: trimmed, in: card.id)
        newChecklistText = ""
    }

    private var cardLabels: [KanbanLabel] {
        labels.filter { card.labelIds.contains($0.id) }
    }

    private func dueLabel(_ due: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: due)
    }
}

private struct FlowChips: View {
    let labels: [KanbanLabel]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(labels, id: \.id) { label in
                Text(label.name)
                    .font(.appFootnote)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill((Color.fromHex(label.colorHex) ?? .accentColor).opacity(0.3))
                    )
            }
        }
    }
}
