import AppKit
import SwiftUI

// Typography baseline derived from the Kanban board (column 21pt / card 19pt / button 18pt / meta 16pt / fine 14pt).
// All other modules must use these tokens — never raw .system(size:) or default text styles
// (which collapse to ~13pt on macOS and made the previous UI feel cramped on the 32:9 Edge display).
//
// Sizing scale:
//   display 40  — hero numerals (clock, large stats)
//   title   22  — module/sheet/section titles, board picker
//   heading 20  — card titles, list-item primary text
//   body    18  — buttons, text fields, primary body copy
//   callout 16  — meta info (due date, location, secondary labels)
//   footnote 14 — counts, badges, fine print primary
//   caption 12  — tooltips/captions/timestamps (do not go below this)

extension Font {
    static let appDisplay = Font.system(size: 40, weight: .light, design: .rounded)
    static let appDisplayMono = Font.system(size: 40, weight: .light, design: .monospaced)

    static let appTitle = Font.system(size: 22, weight: .semibold)
    static let appTitleBold = Font.system(size: 22, weight: .bold)
    static let appTitleMono = Font.system(size: 22, weight: .semibold, design: .monospaced)

    static let appHeading = Font.system(size: 20, weight: .semibold)
    static let appHeadingRegular = Font.system(size: 20)
    static let appHeadingMono = Font.system(size: 20, weight: .semibold, design: .monospaced)

    static let appBody = Font.system(size: 18)
    static let appBodyBold = Font.system(size: 18, weight: .semibold)
    static let appBodyMono = Font.system(size: 18, design: .monospaced)
    static let appBodyMonoBold = Font.system(size: 18, weight: .semibold, design: .monospaced)

    static let appCallout = Font.system(size: 16)
    static let appCalloutBold = Font.system(size: 16, weight: .semibold)
    static let appCalloutMono = Font.system(size: 16, design: .monospaced)

    static let appFootnote = Font.system(size: 14)
    static let appFootnoteBold = Font.system(size: 14, weight: .semibold)
    static let appFootnoteMono = Font.system(size: 14, design: .monospaced)

    static let appCaption = Font.system(size: 12)
    static let appCaptionBold = Font.system(size: 12, weight: .semibold)
    static let appCaptionMono = Font.system(size: 12, design: .monospaced)
}

// Sheet/popup sizing helpers — every sheet should claim 50–80% of the screen width
// instead of hardcoded minWidths that look tiny on the 2560×720 Edge panel.

enum AppSheet {
    /// Returns the visible size of the screen that currently hosts the app window.
    ///
    /// `NSScreen.main` tracks the screen with the active menubar, which on this
    /// dual-monitor setup is the laptop — not the Xeneon Edge panel where the
    /// app actually lives. Sizing sheets against `NSScreen.main` would clip them
    /// or center them on the wrong display, so we resolve the screen via the
    /// key window. `NSScreen.main` is only used during the brief moment between
    /// app launch and first window assignment.
    static func screenSize() -> CGSize {
        let screen = NSApp.keyWindow?.screen ?? NSScreen.main!
        return screen.visibleFrame.size
    }
}

struct AppSheetFrame: ViewModifier {
    let widthRatio: ClosedRange<CGFloat>
    let heightRatio: ClosedRange<CGFloat>

    func body(content: Content) -> some View {
        let size = AppSheet.screenSize()
        let minW = size.width * widthRatio.lowerBound
        let maxW = size.width * widthRatio.upperBound
        let idealW = size.width * ((widthRatio.lowerBound + widthRatio.upperBound) / 2)
        let minH = size.height * heightRatio.lowerBound
        let maxH = size.height * heightRatio.upperBound
        let idealH = size.height * ((heightRatio.lowerBound + heightRatio.upperBound) / 2)
        return content
            .frame(
                minWidth: minW,
                idealWidth: idealW,
                maxWidth: maxW,
                minHeight: minH,
                idealHeight: idealH,
                maxHeight: maxH
            )
    }
}

extension View {
    /// Apply a screen-proportional frame to a sheet/popup.
    /// - Parameters:
    ///   - width: ratio range of the screen width to occupy (default 0.5...0.8).
    ///   - height: ratio range of the screen height to occupy (default 0.5...0.85).
    func appSheetFrame(
        width: ClosedRange<CGFloat> = 0.5...0.8,
        height: ClosedRange<CGFloat> = 0.5...0.85
    ) -> some View {
        modifier(AppSheetFrame(widthRatio: width, heightRatio: height))
    }
}
