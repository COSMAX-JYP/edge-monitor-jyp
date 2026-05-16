import SwiftUI

struct PageBarView: View {
    @Bindable var viewModel: StreamDeckViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    pageChip(page: page, index: index)
                }
                Button {
                    viewModel.startCreatePage()
                } label: {
                    Label("페이지", systemImage: "plus").font(.appBody)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
    }

    private func pageChip(page: StreamDeckPage, index: Int) -> some View {
        let isActive = page.id == viewModel.activePage?.id
        let color = Color.fromHex(page.colorHex) ?? .accentColor
        return Button {
            viewModel.selectPage(page.id)
        } label: {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 12, height: 12)
                Text(page.name)
                    .font(isActive ? .appBodyBold : .appBody)
                if index < 9 {
                    Text("⌘\(index + 1)")
                        .font(.appFootnoteMono)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? color.opacity(0.22) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isActive ? color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("이름 변경") { viewModel.startRenamePage(page) }
            if viewModel.pages.count > 1 {
                Button(role: .destructive) {
                    viewModel.requestDeletePage(page)
                } label: {
                    Label("페이지 삭제", systemImage: "trash")
                }
            }
        }
    }
}

struct PageEditorSheet: View {
    let initial: StreamDeckPage
    var onSave: (StreamDeckPage) -> Void
    var onCancel: () -> Void

    @State private var name: String
    @State private var colorHex: String

    init(initial: StreamDeckPage, onSave: @escaping (StreamDeckPage) -> Void, onCancel: @escaping () -> Void) {
        self.initial = initial
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initial.name)
        _colorHex = State(initialValue: initial.colorHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("페이지 편집").font(.appTitle)
                Spacer()
                Button("취소", action: onCancel).font(.appBody)
                Button("저장") {
                    var page = initial
                    page.name = name.trimmingCharacters(in: .whitespaces)
                    page.colorHex = colorHex
                    onSave(page)
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
                HStack(spacing: 8) {
                    ForEach(["#4A90E2", "#50E3C2", "#7ED321", "#F5A623", "#E94B3C", "#BD10E0", "#9013FE", "#9B9B9B"], id: \.self) { hex in
                        Button {
                            colorHex = hex
                        } label: {
                            Circle()
                                .fill(Color.fromHex(hex) ?? .accentColor)
                                .frame(width: 28, height: 28)
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
            Spacer()
        }
        .padding(24)
        .appSheetFrame(width: 0.4...0.65, height: 0.35...0.6)
    }
}

struct ActionOutputSheet: View {
    let output: ActionOutput
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "terminal").font(.appBody).foregroundStyle(.tint)
                Text(output.label).font(.appTitle)
                Spacer()
                Button("닫기", action: onDismiss)
                    .font(.appBody)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            ScrollView {
                Text(output.text)
                    .font(.appBodyMono)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .padding(24)
        .appSheetFrame(width: 0.5...0.8, height: 0.5...0.85)
    }
}
