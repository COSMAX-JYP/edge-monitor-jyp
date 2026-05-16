import SwiftUI

struct StreamDeckView: View {
    @Bindable var viewModel: StreamDeckViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let page = viewModel.activePage {
                // Tighter outer padding so each tile gets more cell area.
                ButtonGridView(page: page, viewModel: viewModel)
                    .padding(8)
                    .gesture(swipeGesture)
            } else {
                Text("페이지가 없습니다").font(.appBody).foregroundStyle(.secondary)
            }
            if let error = viewModel.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").font(.appBody).foregroundStyle(.red)
                    Text(error).font(.appCallout)
                    Spacer()
                    Button {
                        viewModel.clearError()
                    } label: {
                        Image(systemName: "xmark").font(.appBody)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.1))
            }
        }
        .sheet(item: $viewModel.editingButton) { btn in
            ActionEditorView(
                initial: btn,
                onSave: viewModel.saveButton,
                onCancel: viewModel.cancelEditing,
                onDelete: {
                    viewModel.deleteButton(at: btn.position)
                }
            )
        }
        .sheet(item: $viewModel.editingPage) { page in
            PageEditorSheet(
                initial: page,
                onSave: viewModel.savePageEdit,
                onCancel: viewModel.cancelPageEdit
            )
        }
        .sheet(item: $viewModel.lastOutput) { output in
            ActionOutputSheet(output: output, onDismiss: viewModel.dismissOutput)
        }
        .alert(item: $viewModel.pendingConfirm) { btn in
            Alert(
                title: Text(confirmTitle(for: btn)),
                message: Text(confirmMessage(for: btn)),
                primaryButton: .default(Text("실행"), action: viewModel.confirmAndExecute),
                secondaryButton: .cancel(Text("취소"), action: viewModel.cancelConfirm)
            )
        }
        .alert("페이지를 삭제할까요?", isPresented: pendingDeletePageBinding) {
            Button("취소", role: .cancel, action: viewModel.cancelDeletePage)
            Button("삭제", role: .destructive, action: viewModel.confirmDeletePage)
        } message: {
            Text(viewModel.pendingDeletePage?.name ?? "")
        }
        .sheet(isPresented: $viewModel.isShowingStats) {
            ActionStatsSheet(viewModel: viewModel, onDismiss: viewModel.closeStats)
        }
    }

    private var pendingDeletePageBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingDeletePage != nil },
            set: { if !$0 { viewModel.cancelDeletePage() } }
        )
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 80)
            .onEnded { value in
                if value.translation.width > 80 {
                    viewModel.prevPage()
                } else if value.translation.width < -80 {
                    viewModel.nextPage()
                }
            }
    }

    private func confirmTitle(for btn: StreamDeckButton) -> String {
        "이 액션을 실행할까요?"
    }

    private func confirmMessage(for btn: StreamDeckButton) -> String {
        if btn.label.isEmpty { return btn.action.summary }
        return "\(btn.label)\n\(btn.action.summary)"
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(viewModel.activePage?.name ?? "Pad").font(.appTitle)
            Spacer()
            WebhookTemplatePicker { template in
                viewModel.addButtonFromWebhookTemplate(template)
            }
            .font(.appBody)
            Button {
                viewModel.openStats()
            } label: {
                Label("통계", systemImage: "chart.bar.fill").font(.appBody)
            }
            Button {
                viewModel.toggleEditing()
            } label: {
                Label(
                    viewModel.isEditing ? "완료" : "편집",
                    systemImage: viewModel.isEditing ? "checkmark.circle" : "pencil"
                ).font(.appBodyBold)
            }
            .keyboardShortcut("e", modifiers: .command)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
}
