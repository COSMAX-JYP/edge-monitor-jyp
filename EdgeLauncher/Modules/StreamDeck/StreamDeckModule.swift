import SwiftUI

@MainActor
final class StreamDeckModule: EdgeModule {
    let id = "streamdeck"
    let title = "Pad"
    let iconName = "square.grid.3x3.fill"
    let supportsFullscreen = true

    let store: StreamDeckStore
    let viewModel: StreamDeckViewModel
    private let commandHandlerImpl: StreamDeckCommandHandler

    init(store: StreamDeckStore? = nil, permissionService: PermissionService) {
        let s = store ?? StreamDeckStore()
        self.store = s
        let vm = StreamDeckViewModel(store: s, permission: permissionService)
        self.viewModel = vm
        self.commandHandlerImpl = StreamDeckCommandHandler(viewModel: vm)
    }

    var view: some View { StreamDeckView(viewModel: viewModel) }

    var commandHandler: ModuleCommandHandler? { commandHandlerImpl }
    var requiredPermissions: [PermissionKind] { [.accessibility] }

    func didBecomeActive() {}
    func didResignActive() {}
    func willTerminate() async {
        try? await store.flush()
    }
}

@MainActor
final class StreamDeckCommandHandler: ModuleCommandHandler {
    private let viewModel: StreamDeckViewModel

    init(viewModel: StreamDeckViewModel) {
        self.viewModel = viewModel
    }

    func handle(_ command: ModuleCommand) -> Bool {
        switch command {
        case .editItem:
            viewModel.toggleEditing()
            return true
        case .delete:
            if let pos = viewModel.editingButton?.position {
                viewModel.deleteButton(at: pos)
                return true
            }
            return false
        case .nextDay:
            viewModel.nextPage()
            return true
        case .prevDay:
            viewModel.prevPage()
            return true
        case .slot1, .slot2, .slot3, .slot4, .slot5,
             .slot6, .slot7, .slot8, .slot9:
            if let idx = pageIndex(for: command) {
                viewModel.selectPage(index: idx)
                return true
            }
            return false
        default:
            return false
        }
    }

    private func pageIndex(for command: ModuleCommand) -> Int? {
        switch command {
        case .slot1: return 0
        case .slot2: return 1
        case .slot3: return 2
        case .slot4: return 3
        case .slot5: return 4
        case .slot6: return 5
        case .slot7: return 6
        case .slot8: return 7
        case .slot9: return 8
        default: return nil
        }
    }
}
