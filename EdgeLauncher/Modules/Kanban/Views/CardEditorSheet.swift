import AppKit
import SwiftUI

struct CardEditorSheet: View {
    let initial: KanbanCard
    let labels: [KanbanLabel]
    let isNew: Bool
    var onSave: (KanbanCard) -> Void
    var onCancel: () -> Void

    @State private var title: String
    @State private var notes: String
    @State private var selectedLabels: Set<UUID>
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var assignee: String
    @FocusState private var titleFocused: Bool

    init(
        initial: KanbanCard,
        labels: [KanbanLabel],
        isNew: Bool,
        onSave: @escaping (KanbanCard) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initial = initial
        self.labels = labels
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: initial.title)
        _notes = State(initialValue: initial.notes)
        _selectedLabels = State(initialValue: Set(initial.labelIds))
        _hasDueDate = State(initialValue: initial.dueDate != nil)
        _dueDate = State(initialValue: initial.dueDate ?? Date().addingTimeInterval(3600))
        _assignee = State(initialValue: initial.assignee)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Text(isNew ? "새 카드" : "카드 편집")
                    .font(.appTitle)
                Spacer()
                Button(isNew ? "추가" : "저장") { saveAndDismiss() }
                    .kanbanDialogPrimaryButton()
                    .keyboardShortcut(.return, modifiers: .option)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("제목").font(.appFootnote).foregroundStyle(.secondary)
                TextField("필수", text: $title)
                    .font(.appBody)
                    .textFieldStyle(.roundedBorder)
                    .focused($titleFocused)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("노트").font(.appFootnote).foregroundStyle(.secondary)
                TextEditor(text: $notes)
                    .frame(minHeight: 140, maxHeight: 280)
                    .font(.appBody)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )
            }
            if !labels.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("라벨").font(.appFootnote).foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(labels, id: \.id) { label in
                            let active = selectedLabels.contains(label.id)
                            Button {
                                if active { selectedLabels.remove(label.id) } else { selectedLabels.insert(label.id) }
                            } label: {
                                Text(label.name)
                                    .font(.appFootnote)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill((Color.fromHex(label.colorHex) ?? .accentColor).opacity(active ? 0.6 : 0.18))
                                    )
                                    .foregroundStyle(active ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                Toggle("마감일", isOn: $hasDueDate)
                    .font(.appBody)
                if hasDueDate {
                    DatePicker("", selection: $dueDate)
                        .font(.appBody)
                        .labelsHidden()
                }
                Spacer()
            }
            HStack {
                Text("담당자").font(.appFootnote).foregroundStyle(.secondary)
                TextField("(옵션)", text: $assignee)
                    .font(.appBody)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 800)
                Spacer()
            }
            Spacer()
        }
        .padding(24)
        .background(
            CardEditorShortcutMonitor(isEnabled: canSave) {
                saveAndDismiss()
            }
        )
        .appSheetFrame(width: 0.35...0.56, height: 0.5...0.85)
        .onAppear {
            if isNew {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    titleFocused = true
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveAndDismiss() {
        guard canSave else { return }
        var card = initial
        card.title = title.trimmingCharacters(in: .whitespaces)
        card.notes = notes
        card.labelIds = Array(selectedLabels)
        card.dueDate = hasDueDate ? dueDate : nil
        card.assignee = assignee
        card.updatedAt = Date()
        onSave(card)
    }
}

private struct CardEditorShortcutMonitor: NSViewRepresentable {
    let isEnabled: Bool
    let onOptionReturn: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.installIfNeeded()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onOptionReturn = onOptionReturn
        context.coordinator.installIfNeeded()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.remove()
    }

    final class Coordinator {
        var isEnabled: Bool = false
        var onOptionReturn: () -> Void = {}
        private var monitor: Any?

        func installIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                let isReturn = event.keyCode == 36 || event.keyCode == 76
                guard isEnabled, isReturn, event.modifierFlags.contains(.option) else {
                    return event
                }
                onOptionReturn()
                return nil
            }
        }

        func remove() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
