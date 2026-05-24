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
    static let minPanelWidth: Double = 280
    /// 화면 전체보다 살짝 큰 상한 — 사용자가 자유롭게 늘려도 잘리지 않는다.
    /// NSPanel 자체가 화면 밖으로 나가지 않게 OS 가 보호하므로 실제 표시 폭은 자연 제한.
    static let maxPanelWidth: Double = 5000
    static let minPanelHeight: Double = 320
    static let maxPanelHeight: Double = 5000
    static let minPanelColumnWidth: Double = 180
    static let maxPanelColumnWidth: Double = 800
    static let minAnimationDuration: Double = 0.10
    static let maxAnimationDuration: Double = 0.40

    private enum Keys {
        static let hotKeyCode = "slidepanel.hotkey.keyCode"
        static let hotKeyModifiers = "slidepanel.hotkey.modifiers"
        static let panelWidth = "slidepanel.width"
        static let panelHeight = "slidepanel.height"
        static let panelColumnWidth = "slidepanel.columnWidth"
        static let panelColumnWidths = "slidepanel.columnWidths" // [UUID-string: Double]
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

    /// 사용자가 가장자리 드래그로 조정한 패널 높이. 0 이면 화면 비율(0.92) 기본값 사용.
    var panelHeight: Double {
        get { (defaults.object(forKey: Keys.panelHeight) as? Double) ?? 0 }
        set {
            if newValue <= 0 {
                defaults.removeObject(forKey: Keys.panelHeight)
            } else {
                let clamped = min(Self.maxPanelHeight, max(Self.minPanelHeight, newValue))
                defaults.set(clamped, forKey: Keys.panelHeight)
            }
        }
    }

    /// SlidePad 안 KanbanBoardView 의 컬럼 한 개 폭. 기본 220 (좁은 패널에 한두 컬럼).
    /// 컬럼별 override 가 없을 때의 fallback.
    var panelColumnWidth: Double {
        get { (defaults.object(forKey: Keys.panelColumnWidth) as? Double) ?? 220.0 }
        set {
            let clamped = min(Self.maxPanelColumnWidth, max(Self.minPanelColumnWidth, newValue))
            defaults.set(clamped, forKey: Keys.panelColumnWidth)
        }
    }

    /// 컬럼별 폭 override. 키는 KanbanColumn.id.uuidString, 값은 폭 (pt).
    /// 없으면 panelColumnWidth fallback.
    func columnWidth(for columnId: UUID) -> Double {
        let map = (defaults.dictionary(forKey: Keys.panelColumnWidths) as? [String: Double]) ?? [:]
        if let v = map[columnId.uuidString] { return v }
        return panelColumnWidth
    }

    func setColumnWidth(_ width: Double, for columnId: UUID) {
        var map = (defaults.dictionary(forKey: Keys.panelColumnWidths) as? [String: Double]) ?? [:]
        let clamped = min(Self.maxPanelColumnWidth, max(Self.minPanelColumnWidth, width))
        map[columnId.uuidString] = clamped
        defaults.set(map, forKey: Keys.panelColumnWidths)
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
