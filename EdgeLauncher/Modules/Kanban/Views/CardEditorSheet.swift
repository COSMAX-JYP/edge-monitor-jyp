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
                .frame(width: 360)
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

    // MARK: - 좌측 입력 폼 (mockup 5 — Inline Preview / 명시적 라벨 + 큰 폰트)

    private var formColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 헤더: 타이틀 + 저장/취소
            HStack(spacing: 12) {
                Text(isNew ? "새 카드" : "카드 편집")
                    .font(.system(size: 26, weight: .bold))
                Spacer()
                Button("취소", action: onCancel).kanbanDialogSecondaryButton()
                Button(isNew ? "추가" : "저장") { saveAndDismiss() }
                    .kanbanDialogPrimaryButton()
                    .keyboardShortcut(.return, modifiers: .option)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // 제목
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("제목 *")
                TextField("새 카드 제목", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 18))
                    .focused($titleFocused)
            }

            // 노트
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("노트")
                TextEditor(text: $notes)
                    .frame(minHeight: 180, maxHeight: .infinity)
                    .font(.system(size: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )
            }

            // 마감일 + 담당자
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("마감일")
                    HStack(spacing: 8) {
                        Toggle("", isOn: $hasDueDate).labelsHidden().controlSize(.regular)
                        if hasDueDate {
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .labelsHidden()
                                .font(.system(size: 15))
                        } else {
                            Text("설정 안 함").font(.system(size: 15)).foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("담당자")
                    TextField("@username (옵션)", text: $assignee)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 15))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 라벨
            if !labels.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("라벨")
                    FlowLayout(spacing: 8) {
                        ForEach(labels, id: \.id) { label in
                            let active = selectedLabels.contains(label.id)
                            let color = Color.fromHex(label.colorHex) ?? .accentColor
                            Button {
                                if active { selectedLabels.remove(label.id) } else { selectedLabels.insert(label.id) }
                            } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(color).frame(width: 8, height: 8)
                                    Text(label.name).font(.system(size: 14, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(color.opacity(active ? 0.28 : 0.10)))
                                .overlay(Capsule().strokeBorder(color.opacity(active ? 0.65 : 0), lineWidth: 1.2))
                                .foregroundStyle(active ? Color.primary : Color.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack {
                Text("⌥↵ 저장 · Esc 취소").font(.system(size: 13)).foregroundStyle(.secondary)
                Spacer()
                Text("\(title.count + notes.count) / 8000").font(.system(size: 13, design: .monospaced)).foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(28)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.4)
    }

    // MARK: - 우측 실시간 미리보기 (5번 Inline Preview)

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("실시간 미리보기")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            previewCard
                .padding(.top, 2)

            Spacer()

            Text("저장 후 보드에 보일 모습")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .background(Color.primary.opacity(0.03))
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(3)
            } else {
                Text("제목 없음")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            if !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }
            if hasDueDate || !assignee.isEmpty {
                HStack(spacing: 10) {
                    if hasDueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar").font(.system(size: 12, weight: .semibold))
                            Text(dueDate.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 13, weight: .medium))
                        }.foregroundStyle(.orange)
                    }
                    if !assignee.isEmpty {
                        Text("@\(assignee)").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
            if !selectedLabels.isEmpty {
                FlowLayout(spacing: 5) {
                    ForEach(labels.filter { selectedLabels.contains($0.id) }, id: \.id) { label in
                        let color = Color.fromHex(label.colorHex) ?? .accentColor
                        HStack(spacing: 4) {
                            Circle().fill(color).frame(width: 7, height: 7)
                            Text(label.name).font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(color.opacity(0.20)))
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
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
