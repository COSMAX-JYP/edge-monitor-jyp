import Foundation

enum ModuleCommand: String, CaseIterable, Sendable {
    case newItem
    case editItem
    case delete
    case refresh
    case undo
    case redo
    case search

    case today
    case nextDay
    case prevDay

    case slot1
    case slot2
    case slot3
    case slot4
    case slot5
    case slot6
    case slot7
    case slot8
    case slot9

    static func slot(at index: Int) -> ModuleCommand? {
        switch index {
        case 0: return .slot1
        case 1: return .slot2
        case 2: return .slot3
        case 3: return .slot4
        case 4: return .slot5
        case 5: return .slot6
        case 6: return .slot7
        case 7: return .slot8
        case 8: return .slot9
        default: return nil
        }
    }
}
