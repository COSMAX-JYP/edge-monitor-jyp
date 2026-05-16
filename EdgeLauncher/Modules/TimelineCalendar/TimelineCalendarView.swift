import SwiftUI

struct TimelineCalendarView: View {
    @Bindable var viewModel: TimelineViewModel
    private let layoutWidth: CGFloat
    private let leadingPad: CGFloat = 16
    private let trailingPad: CGFloat = 16
    private let laneHeight: CGFloat = 360

    init(viewModel: TimelineViewModel, contentWidth: CGFloat = 2370) {
        self.viewModel = viewModel
        self.layoutWidth = contentWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                DateHeaderView(viewModel: viewModel)
                Divider()
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let detail = viewModel.detailEvent {
                EventDetailPanel(
                    event: detail,
                    calendars: viewModel.calendars,
                    onEdit: { viewModel.startEditEvent(detail) },
                    onDelete: { viewModel.requestDelete(detail) },
                    onDismiss: { viewModel.dismissDetail() }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .sheet(item: $viewModel.editorDraft) { draft in
            EventEditorSheet(
                initial: draft,
                calendars: viewModel.calendars,
                isNew: viewModel.editorTargetEvent == nil,
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

    private var timeline: some View {
        let ruler = TimeRulerLayout(startHour: 6, endHour: 22, totalWidth: layoutWidth)
        let winStart = ruler.windowStart(on: viewModel.currentDay)
        let winEnd = ruler.windowEnd(on: viewModel.currentDay)
        let placements = EventLayoutEngine.layout(
            events: viewModel.events,
            windowStart: winStart,
            windowEnd: winEnd
        )
        let allDay = EventLayoutEngine.allDayEvents(viewModel.events)

        return VStack(alignment: .leading, spacing: 0) {
            if !allDay.isEmpty {
                allDayBand(events: allDay)
                Divider()
            }
            ScrollView(.horizontal, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    TimelineRulerView(layout: ruler)
                        .frame(width: ruler.totalWidth, height: laneHeight)
                    laneTapLayer(ruler: ruler)
                    TimelineLaneView(
                        placements: placements,
                        layout: ruler,
                        day: viewModel.currentDay,
                        baseColor: .accentColor,
                        laneHeight: laneHeight,
                        onTapEvent: { viewModel.showDetail($0) }
                    )
                    .frame(width: ruler.totalWidth, height: laneHeight)
                    NowIndicatorView(layout: ruler, day: viewModel.currentDay)
                        .frame(width: ruler.totalWidth, height: laneHeight)
                }
                .padding(.horizontal, 8)
            }
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.appFootnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
            if viewModel.events.isEmpty && !viewModel.isLoading {
                Text("표시할 일정이 없습니다 · Cmd+N 으로 추가")
                    .font(.appBody)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            }
        }
    }

    private func laneTapLayer(ruler: TimeRulerLayout) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: ruler.totalWidth, height: laneHeight)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2)
                    .onEnded { value in
                        let snapped = snappedTime(x: value.location.x, ruler: ruler)
                        viewModel.startNewEvent(at: snapped)
                    }
            )
    }

    private func snappedTime(x: CGFloat, ruler: TimeRulerLayout) -> Date {
        let raw = ruler.date(at: x, on: viewModel.currentDay)
        let cal = Calendar.current
        let minute = cal.component(.minute, from: raw)
        let rounded = (minute / 15) * 15
        let hour = cal.component(.hour, from: raw)
        return cal.date(bySettingHour: hour, minute: rounded, second: 0, of: cal.startOfDay(for: viewModel.currentDay)) ?? raw
    }

    private func allDayBand(events: [TimelineEvent]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(events, id: \.id) { event in
                    Text(event.title)
                        .font(.appFootnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.showDetail(event) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}
