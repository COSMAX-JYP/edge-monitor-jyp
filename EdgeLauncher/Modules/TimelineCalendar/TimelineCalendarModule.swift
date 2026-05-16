import SwiftUI

@MainActor
final class TimelineCalendarModule: EdgeModule {
    let id = "timeline"
    let title = "Timeline"
    let iconName = "calendar.day.timeline.left"
    let supportsFullscreen = true

    let viewModel: TimelineViewModel
    private let commandHandlerImpl: TimelineCommandHandler

    init(permissionService: PermissionService) {
        let provider = EventKitProvider()
        let vm = TimelineViewModel(provider: provider, permission: permissionService)
        self.viewModel = vm
        self.commandHandlerImpl = TimelineCommandHandler(viewModel: vm)
    }

    var view: some View {
        TimelineCalendarView(viewModel: viewModel)
    }

    var commandHandler: ModuleCommandHandler? { commandHandlerImpl }

    var requiredPermissions: [PermissionKind] { [.calendar] }

    func didBecomeActive() {
        Task { await viewModel.onAppear() }
    }

    func didResignActive() {}
}

@MainActor
final class TimelineCommandHandler: ModuleCommandHandler {
    private let viewModel: TimelineViewModel

    init(viewModel: TimelineViewModel) {
        self.viewModel = viewModel
    }

    func handle(_ command: ModuleCommand) -> Bool {
        switch command {
        case .refresh:
            Task { await viewModel.reload() }
            return true
        case .today:
            viewModel.goToToday()
            return true
        case .prevDay:
            viewModel.goToPrevious()
            return true
        case .nextDay:
            viewModel.goToNext()
            return true
        case .newItem:
            guard viewModel.permissionState.isUsable, !viewModel.calendars.isEmpty else { return false }
            viewModel.startNewEvent()
            return true
        case .editItem:
            if let event = viewModel.detailEvent {
                viewModel.startEditEvent(event)
                return true
            }
            return false
        case .delete:
            if let event = viewModel.detailEvent {
                viewModel.requestDelete(event)
                return true
            }
            return false
        default:
            return false
        }
    }
}
