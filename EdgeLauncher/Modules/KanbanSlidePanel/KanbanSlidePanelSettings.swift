import Foundation
import Observation
import Carbon.HIToolbox

enum SlidePanelDisplayPolicy: Equatable {
    case mouseLocation
    case mainDisplay
    case specific(displayUUID: String)

    var rawValue: String {
        switch self {
        case .mouseLocation: return "mouse"
        case .mainDisplay: return "main"
        case .specific(let uuid): return "uuid:\(uuid)"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "mouse": self = .mouseLocation
        case "main": self = .mainDisplay
        default:
            if rawValue.hasPrefix("uuid:") {
                self = .specific(displayUUID: String(rawValue.dropFirst(5)))
            } else {
                return nil
            }
        }
    }
}

@Observable
@MainActor
final class KanbanSlidePanelSettings {
    static let defaultHotKeyCode: Int = kVK_ANSI_K
    static let defaultHotKeyModifiers: UInt32 = UInt32(cmdKey | shiftKey)
    static let minPanelWidth: Double = 320
    static let maxPanelWidth: Double = 720
    static let minAnimationDuration: Double = 0.10
    static let maxAnimationDuration: Double = 0.40

    private enum Keys {
        static let hotKeyCode = "slidepanel.hotkey.keyCode"
        static let hotKeyModifiers = "slidepanel.hotkey.modifiers"
        static let panelWidth = "slidepanel.width"
        static let targetDisplay = "slidepanel.targetDisplay"
        static let autoHideOnBlur = "slidepanel.autoHideOnBlur"
        static let autoHideOnEscape = "slidepanel.autoHideOnEscape"
        static let isPinned = "slidepanel.pinned"
        static let slideAnimationDuration = "slidepanel.animationDuration"
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var hotKeyCode: Int {
        get { (defaults.object(forKey: Keys.hotKeyCode) as? Int) ?? Self.defaultHotKeyCode }
        set { defaults.set(newValue, forKey: Keys.hotKeyCode) }
    }

    var hotKeyModifiers: UInt32 {
        get {
            if let raw = defaults.object(forKey: Keys.hotKeyModifiers) as? UInt {
                return UInt32(raw)
            }
            return Self.defaultHotKeyModifiers
        }
        set { defaults.set(UInt(newValue), forKey: Keys.hotKeyModifiers) }
    }

    var panelWidth: Double {
        get { (defaults.object(forKey: Keys.panelWidth) as? Double) ?? 420.0 }
        set {
            let clamped = min(Self.maxPanelWidth, max(Self.minPanelWidth, newValue))
            defaults.set(clamped, forKey: Keys.panelWidth)
        }
    }

    var targetDisplayPolicy: SlidePanelDisplayPolicy {
        get {
            if let raw = defaults.string(forKey: Keys.targetDisplay),
               let p = SlidePanelDisplayPolicy(rawValue: raw) {
                return p
            }
            return .mouseLocation
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.targetDisplay) }
    }

    var autoHideOnBlur: Bool {
        get { defaults.object(forKey: Keys.autoHideOnBlur) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.autoHideOnBlur) }
    }

    var autoHideOnEscape: Bool {
        get { defaults.object(forKey: Keys.autoHideOnEscape) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.autoHideOnEscape) }
    }

    var isPinned: Bool {
        get { defaults.object(forKey: Keys.isPinned) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Keys.isPinned) }
    }

    var slideAnimationDuration: Double {
        get { (defaults.object(forKey: Keys.slideAnimationDuration) as? Double) ?? 0.20 }
        set {
            let clamped = min(Self.maxAnimationDuration, max(Self.minAnimationDuration, newValue))
            defaults.set(clamped, forKey: Keys.slideAnimationDuration)
        }
    }
}
