import SwiftUI

@MainActor
final class KanbanModule: EdgeModule {
    let id = "kanban"
    let title = "Kanban"
    let iconName = "rectangle.split.3x1.fill"
    let supportsFullscreen = true

    let store: KanbanStore
    let viewModel: KanbanViewModel
    private let commandHandlerImpl: KanbanCommandHandler

    init(store: KanbanStore? = nil) {
        let s = store ?? KanbanStore()
        self.store = s
        let vm = KanbanViewModel(store: s)
        self.viewModel = vm
        self.commandHandlerImpl = KanbanCommandHandler(viewModel: vm)
    }

    var view: some View {
        KanbanBoardView(viewModel: viewModel)
    }

    var commandHandler: ModuleCommandHandler? { commandHandlerImpl }

    func didBecomeActive() {}
    func didResignActive() {}

    func willTerminate() async {
        try? await store.flush()
    }
}

@MainActor
final class KanbanCommandHandler: ModuleCommandHandler {
    private let viewModel: KanbanViewModel

    init(viewModel: KanbanViewModel) {
        self.viewModel = viewModel
    }

    func handle(_ command: ModuleCommand) -> Bool {
        switch command {
        case .newItem:
            if let column = viewModel.activeBoard?.columns.first {
                viewModel.startNewCard(in: column.id)
                return true
            }
            return false
        case .editItem:
            if let card = viewModel.detailCard {
                viewModel.editCard(card)
                return true
            }
            return false
        case .delete:
            if let card = viewModel.detailCard {
                viewModel.requestDelete(card)
                return true
            }
            return false
        case .undo:
            if viewModel.canUndo {
                viewModel.undoLastDelete()
                return true
            }
            return false
        case .search:
            return false
        default:
            return false
        }
    }
}
