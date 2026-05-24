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
        HStack(spacing: 0) {
            formColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            previewColumn
                .frame(width: 280)
        }
        .background(
            CardEditorShortcutMonitor(isEnabled: canSave) {
                saveAndDismiss()
            }
        )
        .appSheetFrame(width: 0.45...0.7, height: 0.55...0.88)
        .onAppear {
            if isNew {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    titleFocused = true
                }
            }
        }
    }

    // MARK: - 좌측 입력 폼 (1번 Compact Pill 베이스)

    private var formColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 헤더: 타이틀 + 저장/취소
            HStack(spacing: 12) {
                Text(isNew ? "새 카드" : "카드 편집")
                    .font(.appTitle)
                Spacer()
                Button("취소", action: onCancel).kanbanDialogSecondaryButton()
                Button(isNew ? "추가" : "저장") { saveAndDismiss() }
                    .kanbanDialogPrimaryButton()
                    .keyboardShortcut(.return, modifiers: .option)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // 제목 (큰 보더리스 입력)
            TextField("제목을 입력…", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .semibold))
                .focused($titleFocused)

            // 메타 chip — 마감일/담당자/라벨/우선순위 한 줄
            FlowLayout(spacing: 6) {
                metaChip(
                    icon: "calendar",
                    label: hasDueDate ? dueDate.formatted(date: .abbreviated, time: .omitted) : "마감일",
                    active: hasDueDate,
                    accent: hasDueDate ? .orange : nil
                ) { hasDueDate.toggle() }
                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                        .controlSize(.small)
                }
                metaChip(
                    icon: "person",
                    label: assignee.isEmpty ? "담당자" : "@\(assignee)",
                    active: !assignee.isEmpty,
                    accent: !assignee.isEmpty ? .blue : nil
                ) {
                    // chip 클릭 → assignee 인라인 편집 필드 표시(아래 row 로).
                    assigneeExpanded.toggle()
                }
                ForEach(labels, id: \.id) { label in
                    let active = selectedLabels.contains(label.id)
                    let color = Color.fromHex(label.colorHex) ?? .accentColor
                    Button {
                        if active { selectedLabels.remove(label.id) } else { selectedLabels.insert(label.id) }
                    } label: {
                        HStack(spacing: 4) {
                            Circle().fill(color).frame(width: 6, height: 6)
                            Text(label.name).font(.appCaption)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(color.opacity(active ? 0.25 : 0.10))
                        )
                        .overlay(
                            Capsule().strokeBorder(color.opacity(active ? 0.6 : 0), lineWidth: 1)
                        )
                        .foregroundStyle(active ? Color.primary : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if assigneeExpanded || !assignee.isEmpty {
                TextField("@username", text: $assignee)
                    .textFieldStyle(.roundedBorder)
                    .font(.appCallout)
                    .frame(maxWidth: 320)
            }

            // 노트 — 큰 영역, Markdown 안내
            VStack(alignment: .leading, spacing: 4) {
                Text("노트 (Markdown 지원)").font(.appFootnote).foregroundStyle(.secondary)
                TextEditor(text: $notes)
                    .frame(minHeight: 180, maxHeight: .infinity)
                    .font(.appBody)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )
            }

            HStack {
                Text("⌥↵ 저장 · Esc 취소").font(.appCaption).foregroundStyle(.secondary)
                Spacer()
                Text("\(title.count + notes.count) / 8000").font(.appCaptionMono).foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(24)
    }

    // MARK: - 우측 실시간 미리보기 (5번 Inline Preview)

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("실시간 미리보기")
                .font(.appCaption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            previewCard
                .padding(.top, 4)

            Spacer()

            Text("저장 후 보드에 보일 모습")
                .font(.appCaption).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color.primary.opacity(0.03))
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.appBodyBold)
                    .foregroundStyle(Color.primary)
                    .lineLimit(3)
            } else {
                Text("제목 없음")
                    .font(.appBodyBold)
                    .foregroundStyle(.tertiary)
            }
            if !notes.isEmpty {
                Text(notes)
                    .font(.appFootnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            if hasDueDate || !assignee.isEmpty {
                HStack(spacing: 6) {
                    if hasDueDate {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar").font(.appCaption)
                            Text(dueDate.formatted(date: .abbreviated, time: .omitted)).font(.appCaption)
                        }.foregroundStyle(.orange)
                    }
                    if !assignee.isEmpty {
                        Text("@\(assignee)").font(.appCaption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
            if !selectedLabels.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(labels.filter { selectedLabels.contains($0.id) }, id: \.id) { label in
                        let color = Color.fromHex(label.colorHex) ?? .accentColor
                        HStack(spacing: 3) {
                            Circle().fill(color).frame(width: 5, height: 5)
                            Text(label.name).font(.appCaption)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 1.5)
                        .background(Capsule().fill(color.opacity(0.18)))
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    @State private var assigneeExpanded: Bool = false

    private func metaChip(icon: String, label: String, active: Bool, accent: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.appCaption)
                Text(label).font(.appCaption)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule().fill((accent ?? Color.primary).opacity(active ? 0.18 : 0.07))
            )
            .foregroundStyle(active ? (accent ?? Color.primary) : Color.secondary)
        }
        .buttonStyle(.plain)
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
