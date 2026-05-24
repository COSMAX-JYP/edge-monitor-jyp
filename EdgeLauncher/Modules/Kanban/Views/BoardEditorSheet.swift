import SwiftUI
import AppKit

struct BoardEditorSheet: View {
    let initial: KanbanBoard
    let isNew: Bool
    var onSave: (KanbanBoard) -> Void
    var onCancel: () -> Void

    @State private var name: String
    @State private var colorHex: String

    init(initial: KanbanBoard, isNew: Bool, onSave: @escaping (KanbanBoard) -> Void, onCancel: @escaping () -> Void) {
        self.initial = initial
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initial.name)
        _colorHex = State(initialValue: initial.colorHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(isNew ? "새 보드" : "보드 편집").font(.appTitle)
                Spacer()
                Button("취소", action: onCancel)
                    .kanbanDialogSecondaryButton()
                Button(isNew ? "추가" : "저장") {
                    var board = initial
                    board.name = name.trimmingCharacters(in: .whitespaces)
                    board.colorHex = colorHex
                    onSave(board)
                }
                .kanbanDialogPrimaryButton()
                .keyboardShortcut(.return, modifiers: .option)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("이름").font(.appFootnote).foregroundStyle(.secondary)
                TextField("필수", text: $name)
                    .font(.appBody)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("색상").font(.appFootnote).foregroundStyle(.secondary)
                ColorSwatchPicker(colorHex: $colorHex)
            }
            Spacer()
        }
        .padding(24)
        .appSheetFrame(width: 0.4...0.65, height: 0.35...0.6)
    }
}

struct ColorSwatchPicker: View {
    @Binding var colorHex: String

    private let columns = Array(repeating: GridItem(.fixed(28), spacing: 8), count: 10)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(KanbanColorPalette.presets, id: \.hex) { swatch in
                    Button {
                        colorHex = swatch.hex
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.fromHex(swatch.hex) ?? .accentColor)
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.primary.opacity(colorHex == swatch.hex ? 0.85 : 0.22), lineWidth: colorHex == swatch.hex ? 2 : 1)
                            if colorHex == swatch.hex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                            }
                        }
                        .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("\(swatch.name) \(swatch.hex)")
                }
            }

            HStack(spacing: 10) {
                ColorPicker("", selection: Binding(
                    get: { Color.fromHex(colorHex) ?? .accentColor },
                    set: { if let hex = $0.hexString { colorHex = hex } }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 32)

                TextField("#RRGGBB", text: Binding(
                    get: { colorHex },
                    set: { colorHex = KanbanColorPalette.normalizedHex($0) ?? colorHex }
                ))
                .font(.appCalloutMono)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
            }
        }
    }
}

enum KanbanColorPalette {
    struct Swatch {
        let name: String
        let hex: String
    }

    static let presets: [Swatch] = [
        Swatch(name: "Blue", hex: "#4A90E2"),
        Swatch(name: "Cyan", hex: "#50E3C2"),
        Swatch(name: "Green", hex: "#7ED321"),
        Swatch(name: "Lime", hex: "#B8E986"),
        Swatch(name: "Yellow", hex: "#F8E71C"),
        Swatch(name: "Orange", hex: "#F5A623"),
        Swatch(name: "Red", hex: "#E94B3C"),
        Swatch(name: "Pink", hex: "#FF5FA2"),
        Swatch(name: "Purple", hex: "#BD10E0"),
        Swatch(name: "Violet", hex: "#9013FE"),
        Swatch(name: "Teal", hex: "#00A6A6"),
        Swatch(name: "Indigo", hex: "#2F54EB"),
        Swatch(name: "Mint", hex: "#63D471"),
        Swatch(name: "Brown", hex: "#8B572A"),
        Swatch(name: "Gray", hex: "#9B9B9B"),
        Swatch(name: "Black", hex: "#111827"),
        Swatch(name: "Slate", hex: "#475569"),
        Swatch(name: "Rose", hex: "#E11D48"),
        Swatch(name: "Amber", hex: "#D97706"),
        Swatch(name: "Emerald", hex: "#059669")
    ]

    static func normalizedHex(_ input: String) -> String? {
        var trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("#") {
            trimmed.removeFirst()
        }
        guard trimmed.count <= 6, trimmed.allSatisfy(\.isHexDigit) else { return nil }
        if trimmed.count == 6 {
            return "#\(trimmed)"
        }
        return "#\(trimmed)"
    }
}

extension Color {
    var hexString: String? {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

/// Sheet 안에 inline 으로 들어가는 HSB 슬라이더 + RGB hex 미리보기 picker.
/// NSColorPanel 별창 안 띄움 — 닫힐 때 자동 정리 신경 안 써도 됨.
struct InlineHSBPicker: View {
    @Binding var colorHex: String

    private var color: Color { Color.fromHex(colorHex) ?? .accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 56, height: 56)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))

                VStack(alignment: .leading, spacing: 8) {
                    component(label: "H", value: hueBinding, range: 0...1, gradientColors: hueGradientColors)
                    component(label: "S", value: saturationBinding, range: 0...1, gradientColors: [.white, color])
                    component(label: "B", value: brightnessBinding, range: 0...1, gradientColors: [.black, color])
                }
            }
        }
    }

    private func component(label: String, value: Binding<Double>, range: ClosedRange<Double>, gradientColors: [Color]) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.appCaptionBold).frame(width: 16, alignment: .leading).foregroundStyle(.secondary)
            ZStack(alignment: .leading) {
                LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Slider(value: value, in: range)
                    .controlSize(.small)
                    .tint(.clear)
                    .frame(height: 14)
            }
            Text(String(format: "%.0f", value.wrappedValue * 100))
                .font(.appCaptionMono).foregroundStyle(.secondary).frame(width: 30, alignment: .trailing)
        }
    }

    private var hsb: (Double, Double, Double) {
        let ns = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.white
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b))
    }

    private var hueBinding: Binding<Double> {
        Binding(get: { hsb.0 }, set: { setHSB($0, hsb.1, hsb.2) })
    }
    private var saturationBinding: Binding<Double> {
        Binding(get: { hsb.1 }, set: { setHSB(hsb.0, $0, hsb.2) })
    }
    private var brightnessBinding: Binding<Double> {
        Binding(get: { hsb.2 }, set: { setHSB(hsb.0, hsb.1, $0) })
    }

    private func setHSB(_ h: Double, _ s: Double, _ b: Double) {
        let ns = NSColor(hue: CGFloat(h), saturation: CGFloat(s), brightness: CGFloat(b), alpha: 1.0)
        if let hex = Color(nsColor: ns).toHex() { colorHex = hex }
    }

    private var hueGradientColors: [Color] {
        stride(from: 0.0, through: 1.0, by: 1.0 / 6.0).map { Color(hue: $0, saturation: 1, brightness: 1) }
    }
}

/// NSColorWell 을 SwiftUI 로 노출. 클릭 시 macOS NSColorPanel 표시.
/// 활성화 시 NSColorPanel.level = popUpMenu 로 SlidePad NSPanel(.statusBar) 위에 떠
/// 항상 최상단, 클릭한 well 좌표 옆에 위치, sheet 닫힘 시 자동 close.
struct NativeColorWell: NSViewRepresentable {
    @Binding var selection: Color

    func makeNSView(context: Context) -> NSColorWell {
        let well = TopMostColorWell()
        well.color = NSColor(selection)
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorChanged(_:))
        return well
    }

    func updateNSView(_ nsView: NSColorWell, context: Context) {
        let desired = NSColor(selection)
        if nsView.color != desired { nsView.color = desired }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: NativeColorWell
        init(_ parent: NativeColorWell) { self.parent = parent }
        @objc func colorChanged(_ sender: NSColorWell) {
            parent.selection = Color(nsColor: sender.color)
        }
    }
}

/// activate 시 NSColorPanel 의 level 을 popUpMenu(101) 로 올리고 well 옆에 위치.
final class TopMostColorWell: NSColorWell {
    override func activate(_ exclusive: Bool) {
        super.activate(exclusive)
        let panel = NSColorPanel.shared
        // SlidePad NSPanel 이 .statusBar(25) 라 popUpMenu(101) 가 안정적으로 위.
        panel.level = .popUpMenu
        panel.collectionBehavior.insert(.canJoinAllSpaces)
        panel.collectionBehavior.insert(.fullScreenAuxiliary)
        positionPanelNearWell(panel)
    }

    private func positionPanelNearWell(_ panel: NSPanel) {
        guard let win = self.window else { return }
        let wellRectInWindow = self.convert(self.bounds, to: nil)
        let wellScreenRect = win.convertToScreen(wellRectInWindow)
        // well 의 우측 위에 panel 좌상단을 두되, 화면 밖이면 좌측으로 옮김.
        var origin = NSPoint(x: wellScreenRect.maxX + 12, y: wellScreenRect.maxY)
        if let screen = win.screen {
            let visible = screen.visibleFrame
            let estimatedPanelSize = panel.frame.size
            if origin.x + estimatedPanelSize.width > visible.maxX {
                origin.x = wellScreenRect.minX - estimatedPanelSize.width - 12
            }
            if origin.y - estimatedPanelSize.height < visible.minY {
                origin.y = visible.minY + estimatedPanelSize.height
            }
        }
        panel.setFrameTopLeftPoint(origin)
    }
}

extension Color {
    /// SwiftUI ColorPicker 결과를 "#RRGGBB" 16진 문자열로 변환.
    /// 알파 채널은 무시하고 sRGB 8-bit 로 라운드.
    func toHex() -> String? {
        let ns = NSColor(self)
        guard let rgb = ns.usingColorSpace(.sRGB) else { return nil }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct KanbanColorEditorSheet: View {
    let title: String
    let initialColorHex: String?
    var onSave: (String?) -> Void
    var onCancel: () -> Void

    @State private var colorHex: String
    @State private var usesDefault: Bool

    init(title: String, initialColorHex: String?, onSave: @escaping (String?) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.initialColorHex = initialColorHex
        self.onSave = onSave
        self.onCancel = onCancel
        _colorHex = State(initialValue: initialColorHex ?? "#4A90E2")
        _usesDefault = State(initialValue: initialColorHex == nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.appTitle)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Button("취소", action: onCancel)
                    .kanbanDialogSecondaryButton()
                Button("저장") {
                    onSave(usesDefault ? nil : colorHex)
                }
                .kanbanDialogPrimaryButton()
                .keyboardShortcut(.return, modifiers: .option)
            }

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(usesDefault ? Color.primary.opacity(0.08) : (Color.fromHex(colorHex) ?? .accentColor))
                    .frame(width: 72, height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 6) {
                    Text(usesDefault ? "기본 색상" : colorHex)
                        .font(.appHeading)
                        .foregroundStyle(Color.primary)
                    Toggle("기본 색상 사용", isOn: $usesDefault)
                        .font(.appCallout)
                        .foregroundStyle(Color.primary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("색상 선택").font(.appFootnote).foregroundStyle(.secondary)
                ColorSwatchPicker(colorHex: $colorHex)
                    .disabled(usesDefault)
                    .opacity(usesDefault ? 0.45 : 1)

                Divider().padding(.vertical, 2)
                Text("커스텀").font(.appFootnote).foregroundStyle(.secondary)
                InlineHSBPicker(colorHex: $colorHex)
                    .disabled(usesDefault)
                    .opacity(usesDefault ? 0.45 : 1)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 640, idealWidth: 760, maxWidth: 900, minHeight: 540, idealHeight: 600, maxHeight: 720)
    }
}
