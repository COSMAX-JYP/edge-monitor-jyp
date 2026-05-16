import Foundation
import ApplicationServices
import Carbon.HIToolbox

enum KeystrokeSender {
    static func send(modifiers: KeystrokeModifiers, key: String) async throws {
        guard AXIsProcessTrusted() else {
            throw ActionExecutorError.accessibilityNotAuthorized
        }
        guard !isSecureInputEnabled() else {
            throw ActionExecutorError.secureInputBlocked
        }
        guard let keycode = keycode(for: key) else {
            throw ActionExecutorError.invalidInput("지원하지 않는 키: \(key)")
        }
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(keycode), keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(keycode), keyDown: false) else {
            throw ActionExecutorError.keystrokeFailed("CGEvent 생성 실패")
        }
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private static func isSecureInputEnabled() -> Bool {
        IsSecureEventInputEnabled()
    }

    static func keycode(for key: String) -> Int? {
        let normalized = key.lowercased()
        return keyMap[normalized]
    }

    private static let keyMap: [String: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E,
        "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J,
        "k": kVK_ANSI_K, "l": kVK_ANSI_L, "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O,
        "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X, "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
        "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        "return": kVK_Return, "enter": kVK_Return, "tab": kVK_Tab,
        "space": kVK_Space, "delete": kVK_Delete, "backspace": kVK_Delete,
        "escape": kVK_Escape, "esc": kVK_Escape,
        "up": kVK_UpArrow, "down": kVK_DownArrow,
        "left": kVK_LeftArrow, "right": kVK_RightArrow,
        "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4,
        "f5": kVK_F5, "f6": kVK_F6, "f7": kVK_F7, "f8": kVK_F8,
        "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
        ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period, "/": kVK_ANSI_Slash,
        ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote,
        "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal,
        "[": kVK_ANSI_LeftBracket, "]": kVK_ANSI_RightBracket,
        "\\": kVK_ANSI_Backslash, "`": kVK_ANSI_Grave
    ]
}
