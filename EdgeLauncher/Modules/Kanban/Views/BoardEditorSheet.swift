import SwiftUI

struct BoardEditorSheet: View {
    let initial: KanbanBoard
    let isNew: Bool
    var onSave: (KanbanBoard) -> Void
    var onCancel: () -> Void

    @State private var name: String
    @State private var colorHex: String

    init(initial: KanbanBoard, isNew: Bool, onSave: @escaping (KanbanBoard) -> Void, onCancel: @escaping () -> Void) {
        self.initial = initial
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initial.name)
        _colorHex = State(initialValue: initial.colorHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(isNew ? "새 보드" : "보드 편집").font(.appTitle)
                Spacer()
                Button("취소", action: onCancel).font(.appBody)
                Button(isNew ? "추가" : "저장") {
                    var board = initial
                    board.name = name.trimmingCharacters(in: .whitespaces)
                    board.colorHex = colorHex
                    onSave(board)
                }
                .font(.appBodyBold)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("이름").font(.appFootnote).foregroundStyle(.secondary)
                TextField("필수", text: $name)
                    .font(.appBody)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("색상").font(.appFootnote).foregroundStyle(.secondary)
                ColorSwatchPicker(colorHex: $colorHex)
            }
            Spacer()
        }
        .padding(24)
        .appSheetFrame(width: 0.4...0.65, height: 0.35...0.6)
    }
}

struct ColorSwatchPicker: View {
    @Binding var colorHex: String

    private let palette: [String] = [
        "#4A90E2", "#50E3C2", "#7ED321", "#F5A623",
        "#E94B3C", "#BD10E0", "#9013FE", "#417505",
        "#9B9B9B", "#000000"
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(palette, id: \.self) { hex in
                Button {
                    colorHex = hex
                } label: {
                    Circle()
                        .fill(Color.fromHex(hex) ?? .accentColor)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: colorHex == hex ? "checkmark" : "")
                                .font(.appCaptionBold)
                                .foregroundStyle(.white)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
