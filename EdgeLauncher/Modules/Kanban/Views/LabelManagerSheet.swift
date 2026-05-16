import SwiftUI

struct LabelManagerSheet: View {
    let labels: [KanbanLabel]
    var onAdd: (String, String) -> Void
    var onUpdate: (KanbanLabel) -> Void
    var onDelete: (UUID) -> Void
    var onDismiss: () -> Void

    @State private var newName: String = ""
    @State private var newColorHex: String = "#4A90E2"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("라벨 관리").font(.appTitle)
                Spacer()
                Button("닫기", action: onDismiss)
                    .font(.appBody)
                    .keyboardShortcut(.escape, modifiers: [])
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("새 라벨").font(.appFootnote).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("이름", text: $newName)
                        .font(.appBody)
                        .textFieldStyle(.roundedBorder)
                    ColorSwatchPicker(colorHex: $newColorHex)
                    Button("추가") {
                        let trimmed = newName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed, newColorHex)
                        newName = ""
                    }
                    .font(.appBodyBold)
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Divider()
            if labels.isEmpty {
                Text("아직 라벨이 없습니다").font(.appBody).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(labels, id: \.id) { label in
                            LabelRow(label: label, onUpdate: onUpdate, onDelete: onDelete)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(24)
        .appSheetFrame(width: 0.45...0.7, height: 0.45...0.75)
    }
}

private struct LabelRow: View {
    let label: KanbanLabel
    var onUpdate: (KanbanLabel) -> Void
    var onDelete: (UUID) -> Void

    @State private var name: String
    @State private var colorHex: String
    @State private var isDirty = false

    init(label: KanbanLabel, onUpdate: @escaping (KanbanLabel) -> Void, onDelete: @escaping (UUID) -> Void) {
        self.label = label
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _name = State(initialValue: label.name)
        _colorHex = State(initialValue: label.colorHex)
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("이름", text: $name)
                .font(.appBody)
                .textFieldStyle(.roundedBorder)
                .onChange(of: name) { _, _ in isDirty = true }
            ColorSwatchPicker(colorHex: $colorHex)
                .onChange(of: colorHex) { _, _ in isDirty = true }
            if isDirty {
                Button("저장") {
                    var updated = label
                    updated.name = name.trimmingCharacters(in: .whitespaces)
                    updated.colorHex = colorHex
                    onUpdate(updated)
                    isDirty = false
                }
                .font(.appBody)
            }
            Button(role: .destructive) {
                onDelete(label.id)
            } label: {
                Image(systemName: "trash").font(.appBody)
            }
        }
        .padding(.vertical, 4)
    }
}
