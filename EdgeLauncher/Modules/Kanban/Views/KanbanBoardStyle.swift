import SwiftUI

struct KanbanBoardStyle {
    let isLight: Bool

    var boardBackground: Color {
        isLight ? Color(red: 0.965, green: 0.975, blue: 0.992) : Color(red: 0.043, green: 0.047, blue: 0.078)
    }

    var divider: Color {
        isLight ? Color(red: 0.86, green: 0.89, blue: 0.94) : Color(red: 0.16, green: 0.17, blue: 0.29)
    }

    var columnFill: Color {
        isLight ? .white : Color(red: 0.063, green: 0.071, blue: 0.121)
    }

    var columnLine: Color {
        isLight ? Color(red: 0.86, green: 0.89, blue: 0.94) : Color(red: 0.18, green: 0.20, blue: 0.34)
    }

    var cardFill: Color {
        isLight ? .white : Color(red: 0.084, green: 0.087, blue: 0.151)
    }

    var cardLine: Color {
        isLight ? Color(red: 0.86, green: 0.89, blue: 0.94) : Color(red: 0.21, green: 0.22, blue: 0.39)
    }

    var tagFill: Color {
        isLight ? Color(red: 0.88, green: 0.97, blue: 0.95) : Color(red: 0.21, green: 0.13, blue: 0.32)
    }

    var tagText: Color {
        isLight ? Color(red: 0.12, green: 0.50, blue: 0.45) : Color(red: 0.87, green: 0.65, blue: 1.0)
    }

    var headerFill: Color {
        isLight ? Color.white.opacity(0.82) : Color(red: 0.063, green: 0.071, blue: 0.121).opacity(0.92)
    }

    var defaultAccent: Color {
        isLight ? Color(red: 0.22, green: 0.49, blue: 0.96) : Color(red: 1.0, green: 0.37, blue: 0.66)
    }

    func accent(from hex: String?) -> Color {
        if let hex, let color = Color.fromHex(hex) {
            return color
        }
        return defaultAccent
    }

    func columnBackground(accent: Color, hasCustomColor: Bool) -> Color {
        if isLight {
            return columnFill
        }
        return hasCustomColor ? accent.opacity(0.07) : columnFill
    }

    func columnStroke(accent: Color, hasCustomColor: Bool, isDropTargeted: Bool) -> Color {
        if isDropTargeted {
            return accent.opacity(isLight ? 0.95 : 0.9)
        }
        if hasCustomColor {
            return accent.opacity(isLight ? 0.48 : 0.72)
        }
        return columnLine
    }
}
