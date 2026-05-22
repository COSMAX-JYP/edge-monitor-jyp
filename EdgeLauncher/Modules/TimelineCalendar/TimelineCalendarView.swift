import SwiftUI

struct TimelineCalendarView: View {
    @Bindable var viewModel: TimelineViewModel
    private let layout: VerticalRulerLayout

    init(viewModel: TimelineViewModel, pixelsPerHour: CGFloat = 60) {
        self.viewModel = viewModel
        self.layout = VerticalRulerLayout(startHour: 0, endHour: 24, pixelsPerHour: pixelsPerHour)
    }

    var body: some View {
        HStack(spacing: 0) {
            if viewModel.sidebarVisible {
                CalendarSidebarView(viewModel: viewModel)
                    .transition(.move(edge: .leading))
                Divider()
            }

            VStack(spacing: 0) {
                DateHeaderView(viewModel: viewModel)
                Divider()
                content
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.appFootnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let detail = viewModel.detailEvent {
                EventDetailPanel(
                    event: detail,
                    calendars: viewModel.calendars,
                    onEdit: { viewModel.startEditEvent(detail) },
                    onDelete: { viewModel.requestDelete(detail) },
                    onDismiss: { viewModel.dismissDetail() },
                    onRespond: { action, comment in
                        Task { await viewModel.respondToOutlookEvent(detail, action: action, comment: comment) }
                    }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.sidebarVisible)
        .task {
            await viewModel.onAppear()
        }
        .dismissiblePopup(item: $viewModel.editorDraft, onDismiss: viewModel.cancelEditing) { draft in
            EventEditorSheet(
                initial: draft,
                calendars: viewModel.calendars,
                isNew: viewModel.editorTargetEvent == nil,
                attendeeSearchService: viewModel.attendeeSearchService,
                onSave: { updated in
                    await viewModel.saveEditor(updated)
                },
                onCancel: viewModel.cancelEditing
            )
        }
        .alert(item: $viewModel.pendingDeleteEvent) { event in
            Alert(
                title: Text("일정을 삭제할까요?"),
                message: Text(event.title),
                primaryButton: .destructive(Text("삭제"), action: {
                    Task { await viewModel.confirmDelete() }
                }),
                secondaryButton: .cancel(Text("취소"), action: viewModel.cancelDelete)
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.permissionState {
        case .authorized, .writeOnly:
            timeline
        case .notDetermined, .unknown:
            PermissionPromptView(
                kind: .calendar,
                state: viewModel.permissionState,
                title: "캘린더 접근 권한이 필요합니다",
                detail: "오늘 일정을 타임라인에 표시하려면 macOS 캘린더 접근 권한을 허용해 주세요.",
                requestAction: { await viewModel.requestPermission() },
                openSettings: { viewModel.openSettings() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied, .restricted:
            PermissionPromptView(
                kind: .calendar,
                state: viewModel.permissionState,
                title: "캘린더 접근이 거부되어 있습니다",
                detail: "시스템 설정 > 개인정보 보호 및 보안 > 캘린더 에서 EdgeLauncher 를 허용해 주세요.",
                requestAction: { await viewModel.requestPermission() },
                openSettings: { viewModel.openSettings() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var timeline: some View {
        switch viewModel.viewMode {
        case .day:
            DayView(viewModel: viewModel, day: viewModel.currentDay, layout: layout)
        case .week:
            WeekView(viewModel: viewModel, layout: layout)
        case .month:
            MonthView(viewModel: viewModel)
        }
    }
}
