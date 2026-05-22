import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Main editor

struct ActionEditorView: View {
    let initial: StreamDeckButton
    var onSave: (StreamDeckButton) -> Void
    var onCancel: () -> Void
    var onDelete: () -> Void

    @State private var label: String
    @State private var iconType: IconType
    @State private var iconSymbolValue: String
    @State private var iconEmojiValue: String
    @State private var iconImageValue: String
    @State private var iconScale: Double
    @State private var backgroundHex: String
    @State private var foregroundHex: String
    @State private var labelColorHex: String
    @State private var labelFontName: String
    @State private var kind: StreamDeckActionKind
    @State private var bundleId: String
    @State private var urlString: String
    @State private var modifierCommand: Bool
    @State private var modifierOption: Bool
    @State private var modifierControl: Bool
    @State private var modifierShift: Bool
    @State private var keyChar: String
    @State private var shellCommand: String
    @State private var shellTimeout: Int
    @State private var shellRequireConfirm: Bool
    @State private var appleScriptSource: String
    @State private var appleScriptRequireConfirm: Bool
    @State private var pasteText: String
    @State private var pasteRestoreClipboard: Bool

    init(
        initial: StreamDeckButton,
        onSave: @escaping (StreamDeckButton) -> Void,
        onCancel: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.initial = initial
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        _label = State(initialValue: initial.label)
        _iconType = State(initialValue: initial.icon.type)
        _iconSymbolValue = State(initialValue: initial.icon.type == .sfSymbol ? initial.icon.value : "")
        _iconEmojiValue = State(initialValue: initial.icon.type == .emoji ? initial.icon.value : "")
        _iconImageValue = State(initialValue: initial.icon.type == .image ? initial.icon.value : "")
        _iconScale = State(initialValue: initial.icon.effectiveScale)
        _backgroundHex = State(initialValue: initial.backgroundHex)
        _foregroundHex = State(initialValue: initial.foregroundHex)
        _labelColorHex = State(initialValue: initial.labelColorHex ?? "")
        _labelFontName = State(initialValue: initial.labelFontName ?? "")
        switch initial.action {
        case .none, .launchApp:
            _kind = State(initialValue: .launchApp)
        case .openURL:
            _kind = State(initialValue: .openURL)
        case .keystroke:
            _kind = State(initialValue: .keystroke)
        case .runShell:
            _kind = State(initialValue: .shell)
        case .appleScript:
            _kind = State(initialValue: .appleScript)
        case .pasteText:
            _kind = State(initialValue: .pasteText)
        case .webhook:
            _kind = State(initialValue: .webhook)
        case .aiPrompt:
            _kind = State(initialValue: .aiPrompt)
        case .multi:
            _kind = State(initialValue: .multi)
        }
        _bundleId = State(initialValue: {
            if case .launchApp(let id) = initial.action { return id }
            return ""
        }())
        _urlString = State(initialValue: {
            if case .openURL(let url) = initial.action { return url }
            return ""
        }())
        if case .keystroke(let mods, let key) = initial.action {
            _modifierCommand = State(initialValue: mods.contains(.command))
            _modifierOption = State(initialValue: mods.contains(.option))
            _modifierControl = State(initialValue: mods.contains(.control))
            _modifierShift = State(initialValue: mods.contains(.shift))
            _keyChar = State(initialValue: key)
        } else {
            _modifierCommand = State(initialValue: true)
            _modifierOption = State(initialValue: false)
            _modifierControl = State(initialValue: false)
            _modifierShift = State(initialValue: false)
            _keyChar = State(initialValue: "")
        }
        if case .runShell(let cmd, let confirm, let timeout) = initial.action {
            _shellCommand = State(initialValue: cmd)
            _shellTimeout = State(initialValue: timeout)
            _shellRequireConfirm = State(initialValue: confirm)
        } else {
            _shellCommand = State(initialValue: "")
            _shellTimeout = State(initialValue: 30)
            _shellRequireConfirm = State(initialValue: true)
        }
        if case .appleScript(let src, let confirm) = initial.action {
            _appleScriptSource = State(initialValue: src)
            _appleScriptRequireConfirm = State(initialValue: confirm)
        } else {
            _appleScriptSource = State(initialValue: "")
            _appleScriptRequireConfirm = State(initialValue: true)
        }
        if case .pasteText(let text, let restore) = initial.action {
            _pasteText = State(initialValue: text)
            _pasteRestoreClipboard = State(initialValue: restore)
        } else {
            _pasteText = State(initialValue: "")
            _pasteRestoreClipboard = State(initialValue: true)
        }
    }

    var body: some View {
        // Container-relative sizing via GeometryReader — the popup shell hands us the
        // launcher main area (StreamDeckView), and we lay out within it. Left column
        // width scales with the container so labels never get squeezed below their
        // intrinsic width (the original bug where 200pt-wide left column center-clipped
        // its children).
        GeometryReader { proxy in
            let leftWidth = min(max(proxy.size.width * 0.32, 380), 560)
            VStack(spacing: 0) {
                header
                Divider()
                HStack(alignment: .top, spacing: 0) {
                    leftPane
                        .frame(width: leftWidth, alignment: .topLeading)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                    Divider()
                    rightPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(minWidth: 900, minHeight: 520)
    }

    // MARK: - Header bar

    private var header: some View {
        HStack(spacing: 10) {
            Text("Pad 버튼 편집").font(.appHeading)
            Text(kind.label)
                .font(.appFootnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(Color.secondary.opacity(0.15))
                )
            Spacer()
            Button("취소") { onCancel() }
                .font(.appCallout)
                .keyboardShortcut(.cancelAction)
            if !isNewButton {
                Button(role: .destructive) { onDelete() } label: {
                    Label("삭제", systemImage: "trash")
                }
                .font(.appCallout)
            }
            Button {
                saveAndDismiss()
            } label: {
                Label("저장", systemImage: "checkmark")
                    .font(.appCalloutBold)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!isValid)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    // MARK: - Left pane: identity + appearance (2-column inner layout)

    private var leftPane: some View {
        // CRITICAL: `.frame(width:)` defaults to .center alignment. Children wider than
        // the requested width get center-clipped — that's why "표시될 텍스트 (옵션)"
        // showed up as "텍스트 (옵션)" (left side cut). Always pass alignment: .topLeading
        // when constraining width on a leading-aligned column.
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                previewBlock
                labelField
                labelStyleBlock
                sizeBlock
                colorBlock
                Spacer(minLength: 0)
            }
            .frame(width: 280, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 8) {
                iconBlock
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(18)
    }

    private var previewBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionHeader("미리보기")
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.18))
                StreamDeckButtonView(
                    button: previewButton,
                    isExecuting: false,
                    isFlashing: false,
                    isEditing: false,
                    onTap: {},
                    onEdit: {},
                    onDelete: {}
                )
                .frame(width: 120, height: 120)
                .allowsHitTesting(false)
            }
            .frame(height: 142)
            .frame(maxWidth: .infinity)
        }
    }

    private var labelField: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("라벨")
            TextField("표시될 텍스트 (옵션)", text: $label)
                .textFieldStyle(.roundedBorder)
                .font(.appCallout)
        }
    }

    private var labelStyleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("라벨 스타일")
            HStack(spacing: 6) {
                Text("폰트")
                    .font(.appFootnoteBold)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
                Picker("", selection: $labelFontName) {
                    Text("시스템 (기본)").tag("")
                    ForEach(LabelFontPalette.curated, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
            }
            ColorSwatchField(
                label: "글자",
                hex: $labelColorHex,
                fallback: foregroundHex.isEmpty ? "#FFFFFF" : foregroundHex,
                presets: ColorPalette.foregrounds
            )
        }
    }

    private var iconBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("아이콘")
            Picker("", selection: $iconType) {
                Text("SF").tag(IconType.sfSymbol)
                Text("이모지").tag(IconType.emoji)
                Text("이미지").tag(IconType.image)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)

            switch iconType {
            case .sfSymbol:
                SFSymbolPicker(value: $iconSymbolValue)
            case .emoji:
                EmojiPicker(value: $iconEmojiValue)
            case .image:
                ImageIconPicker(value: $iconImageValue)
            }
        }
    }

    private var sizeBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                sectionHeader("크기")
                Spacer()
                Text("\(Int(iconScale * 100))%")
                    .font(.appFootnoteMono)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $iconScale, in: IconSpec.minScale...IconSpec.maxScale)
                .controlSize(.small)
        }
    }

    private var colorBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("색상")
            ColorSwatchField(label: "배경", hex: $backgroundHex, fallback: "#2C2C2E", presets: ColorPalette.backgrounds)
            ColorSwatchField(label: "전경", hex: $foregroundHex, fallback: "#FFFFFF", presets: ColorPalette.foregrounds)
        }
    }

    // MARK: - Right pane: action behavior

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("액션 타입")
            ActionKindGrid(selection: $kind)
            Divider().padding(.vertical, 2)
            actionForm
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var actionForm: some View {
        switch kind {
        case .launchApp:
            launchAppForm
        case .openURL:
            openURLForm
        case .keystroke:
            keystrokeForm
        case .shell:
            shellForm
        case .appleScript:
            appleScriptForm
        case .pasteText:
            pasteTextForm
        case .webhook, .aiPrompt, .multi:
            unsupportedActionForm
        }
    }

    private var openURLForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledField(label: "URL", placeholder: "https://", text: $urlString, monospaced: true)
            Text("브라우저 기본값으로 열립니다. file://, mailto:, raycast:// 같은 스킴도 지원.")
                .font(.appCaption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Action-specific forms

    private var launchAppForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledField(label: "Bundle Identifier", placeholder: "예: com.apple.Notes", text: $bundleId, monospaced: true)
            HStack {
                Button {
                    pickAppBundle()
                } label: {
                    Label("앱 선택…", systemImage: "app.badge")
                }
                .font(.appCallout)
                Spacer()
            }
            Text("Bundle ID를 모르면 위 버튼으로 앱을 선택하세요.")
                .font(.appCaption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var keystrokeForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Modifier + Key")
            HStack(spacing: 6) {
                ModifierToggle(label: "⌘", isOn: $modifierCommand)
                ModifierToggle(label: "⌥", isOn: $modifierOption)
                ModifierToggle(label: "⌃", isOn: $modifierControl)
                ModifierToggle(label: "⇧", isOn: $modifierShift)
                Spacer()
            }
            LabeledField(label: "Key", placeholder: "예: a, return, space, f5", text: $keyChar, monospaced: true)
            Text("주의: 손쉬운 사용 권한이 필요합니다.")
                .font(.appCaption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var shellForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Shell 명령")
            CodeEditor(text: $shellCommand, flexible: true)
            HStack(spacing: 14) {
                Toggle("실행 전 확인", isOn: $shellRequireConfirm).font(.appCallout)
                Spacer()
                Stepper("타임아웃 \(shellTimeout)초", value: $shellTimeout, in: 1...600)
                    .font(.appCallout)
                    .fixedSize()
            }
            Text("주의: /bin/sh -c 로 실행. 출력은 별도 시트로 표시.")
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var appleScriptForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("AppleScript")
            CodeEditor(text: $appleScriptSource, flexible: true)
            Toggle("실행 전 확인", isOn: $appleScriptRequireConfirm).font(.appCallout)
            Text("주의: 대상 앱별 자동화 권한 다이얼로그가 뜰 수 있습니다.")
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var pasteTextForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("붙여넣을 텍스트")
            CodeEditor(text: $pasteText, flexible: true, monospaced: false)
            Toggle("원래 클립보드 복원", isOn: $pasteRestoreClipboard).font(.appCallout)
            Text("Cmd+V 를 시뮬레이션합니다. 손쉬운 사용 권한 필요.")
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var unsupportedActionForm: some View {
        VStack(alignment: .center, spacing: 10) {
            Spacer()
            Image(systemName: "wrench.adjustable")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("\(kind.label) 편집 UI는 아직 준비 중입니다.")
                .font(.appCallout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.appFootnoteBold)
            .foregroundStyle(.secondary)
    }

    private var activeIconValue: String {
        switch iconType {
        case .sfSymbol: return iconSymbolValue
        case .emoji: return iconEmojiValue
        case .image: return iconImageValue
        }
    }

    private var previewButton: StreamDeckButton {
        var b = initial
        b.label = label
        b.icon = IconSpec(type: iconType, value: activeIconValue, scale: iconScale)
        b.backgroundHex = backgroundHex.isEmpty ? "#2C2C2E" : backgroundHex
        b.foregroundHex = foregroundHex.isEmpty ? "#FFFFFF" : foregroundHex
        b.labelColorHex = labelColorHex.isEmpty ? nil : labelColorHex
        b.labelFontName = labelFontName.isEmpty ? nil : labelFontName
        return b
    }

    private var isNewButton: Bool {
        if case .none = initial.action, initial.label.isEmpty { return true }
        return false
    }

    private var isValid: Bool {
        switch kind {
        case .launchApp: return !bundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .openURL: return validURLString != nil
        case .keystroke: return !keyChar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .shell: return !shellCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .appleScript: return !appleScriptSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .pasteText: return !pasteText.isEmpty
        case .webhook, .aiPrompt, .multi:
            // Editor doesn't author these from scratch, but if the existing button already
            // has one of these actions we must let the user save label/icon/color tweaks.
            return initial.action.kindLabel == kind.label
        }
    }

    private var validURLString: String? {
        let raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), let scheme = url.scheme, !scheme.isEmpty else {
            return nil
        }
        return raw
    }

    private func saveAndDismiss() {
        var btn = initial
        btn.label = label
        btn.icon = IconSpec(type: iconType, value: activeIconValue, scale: iconScale)
        btn.backgroundHex = backgroundHex.isEmpty ? "#2C2C2E" : backgroundHex
        btn.foregroundHex = foregroundHex.isEmpty ? "#FFFFFF" : foregroundHex
        btn.labelColorHex = labelColorHex.isEmpty ? nil : labelColorHex
        btn.labelFontName = labelFontName.isEmpty ? nil : labelFontName
        switch kind {
        case .launchApp:
            btn.action = .launchApp(bundleId: bundleId.trimmingCharacters(in: .whitespaces))
        case .openURL:
            guard let validURLString else { return }
            btn.action = .openURL(url: validURLString)
        case .keystroke:
            var mods: KeystrokeModifiers = []
            if modifierCommand { mods.insert(.command) }
            if modifierOption { mods.insert(.option) }
            if modifierControl { mods.insert(.control) }
            if modifierShift { mods.insert(.shift) }
            btn.action = .keystroke(modifiers: mods, key: keyChar.trimmingCharacters(in: .whitespaces))
        case .shell:
            btn.action = .runShell(
                command: shellCommand.trimmingCharacters(in: .whitespacesAndNewlines),
                requireConfirm: shellRequireConfirm,
                timeoutSeconds: shellTimeout
            )
        case .appleScript:
            btn.action = .appleScript(
                source: appleScriptSource,
                requireConfirm: appleScriptRequireConfirm
            )
        case .pasteText:
            btn.action = .pasteText(text: pasteText, restoreClipboard: pasteRestoreClipboard)
        case .webhook, .aiPrompt, .multi:
            // Editor doesn't construct these; keep whatever the button already had
            // so the user can still save label/icon/color edits without losing the action.
            guard initial.action.kindLabel == kind.label else { return }
            btn.action = initial.action
        }
        btn.updatedAt = Date()
        onSave(btn)
    }

    private func pickAppBundle() {
        let panel = NSOpenPanel()
        panel.title = "앱 선택"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK,
           let url = panel.url,
           let bundle = Bundle(url: url),
           let id = bundle.bundleIdentifier {
            bundleId = id
            if label.isEmpty {
                label = (url.deletingPathExtension().lastPathComponent)
            }
        }
    }
}

// MARK: - Action kind grid

private struct ActionKindGrid: View {
    @Binding var selection: StreamDeckActionKind
    private let columns = [GridItem(.adaptive(minimum: 112, maximum: 170), spacing: 6)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(StreamDeckActionKind.allCases, id: \.self) { kind in
                let isSelected = selection == kind
                Button {
                    selection = kind
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: kind.sfSymbol)
                            .frame(width: 16)
                        Text(kind.label)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                    }
                    .font(.appCallout)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.2)
                    )
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - SF Symbol picker

private struct SFSymbolPicker: View {
    @Binding var value: String
    @State private var query: String = ""

    private static let curated: [String] = [
        "bolt.fill", "link", "terminal", "scroll", "doc.on.clipboard", "network",
        "sparkles", "square.grid.3x3.fill", "app.dashed", "keyboard",
        "gearshape.fill", "globe", "envelope.fill", "message.fill",
        "calendar", "calendar.badge.clock", "folder.fill", "phone.fill",
        "phone.connection.fill", "note.text", "magnifyingglass", "star.fill",
        "heart.fill", "flag.fill", "bookmark.fill", "tag.fill",
        "house.fill", "person.fill", "person.2.fill", "lock.fill", "lock.open.fill",
        "trash.fill", "pencil", "paintbrush.fill", "paintpalette.fill",
        "hammer.fill", "wrench.fill", "command", "option", "control", "shift",
        "power", "eye.fill", "eye.slash.fill", "info.circle.fill",
        "questionmark.circle.fill", "exclamationmark.triangle.fill",
        "play.fill", "pause.fill", "stop.fill", "forward.fill", "backward.fill",
        "arrow.up", "arrow.down", "arrow.left", "arrow.right",
        "arrow.triangle.2.circlepath", "arrow.clockwise",
        "music.note", "photo.fill", "video.fill", "mic.fill", "speaker.wave.2.fill",
        "chart.bar.fill", "chart.pie.fill", "chart.line.uptrend.xyaxis",
        "cylinder.split.1x2.fill", "externaldrive.fill", "server.rack",
        "text.bubble.fill", "bubble.left.fill", "camera.fill",
        "paperplane.fill", "paperclip", "scissors", "tablecells.fill",
        "checkmark.circle.fill", "xmark.circle.fill", "plus.circle.fill",
        "minus.circle.fill", "building.2.fill", "doc.text.fill", "sun.max.fill",
        "moon.fill", "diamond.fill", "shippingbox.fill"
    ]

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return Self.curated }
        return Self.curated.filter { $0.contains(q) }
    }

    private let columns = [GridItem(.adaptive(minimum: 38, maximum: 56), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                TextField("검색", text: $query)
                    .textFieldStyle(.plain)
                    .font(.appCallout)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.secondary.opacity(0.1))
            )

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(filtered, id: \.self) { name in
                        Button {
                            value = name
                        } label: {
                            Image(systemName: name)
                                .font(.system(size: 18))
                                .frame(width: 38, height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(value == name ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(value == name ? Color.accentColor : Color.clear, lineWidth: 1.4)
                                )
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .help(name)
                    }
                }
                .padding(.trailing, 2)
            }
            .scrollIndicators(.never)
            .frame(height: 240)

            TextField("심볼명 직접 입력", text: $value)
                .textFieldStyle(.roundedBorder)
                .font(.appCalloutMono)
        }
    }
}

// MARK: - Emoji picker

private struct EmojiPicker: View {
    @Binding var value: String

    private static let curated: [String] = [
        "🚀", "💡", "🔥", "⭐", "❤️", "🎯", "✅", "❌", "⚠️", "🔒",
        "🔓", "🔑", "📌", "📍", "📂", "📁", "📝", "✏️", "🔍", "🛠️",
        "🎨", "🖥️", "💻", "📱", "🌐", "📧", "💬", "🔔", "🔊", "🎵",
        "🎬", "📷", "📊", "📈", "📉", "🗂️", "🗒️", "📋", "🗃️", "💾",
        "⚡", "🌙", "☀️", "🌈", "🎮", "🎲", "🧩", "🪄", "🧪", "⚙️",
        "🏠", "🏢", "🚗", "✈️", "🛸", "🎁", "🍕", "☕", "🥤", "🍔"
    ]

    private let columns = [GridItem(.adaptive(minimum: 38, maximum: 56), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(Self.curated, id: \.self) { e in
                        Button {
                            value = e
                        } label: {
                            Text(e)
                                .font(.system(size: 24))
                                .frame(width: 38, height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(value == e ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(value == e ? Color.accentColor : Color.clear, lineWidth: 1.4)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 2)
            }
            .scrollIndicators(.never)
            .frame(height: 240)

            HStack(spacing: 6) {
                TextField("이모지 직접 입력", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16))
                Button {
                    NSApp.orderFrontCharacterPalette(nil)
                } label: {
                    Image(systemName: "face.smiling")
                }
                .font(.appCallout)
                .help("이모지 패널")
            }
        }
    }
}

// MARK: - Image icon picker

private struct ImageIconPicker: View {
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                thumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        pickImage()
                    } label: {
                        Label(value.isEmpty ? "선택…" : "변경…", systemImage: "photo.on.rectangle")
                    }
                    .font(.appCallout)
                    if !value.isEmpty {
                        Button(role: .destructive) {
                            ButtonIconStorage.shared.remove(filename: value)
                            value = ""
                        } label: {
                            Label("제거", systemImage: "trash")
                        }
                        .font(.appFootnote)
                    }
                }
                Spacer()
            }
            Text("PNG, JPEG, HEIC, SVG, GIF — 앱 폴더로 복사")
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
            if !value.isEmpty,
               let img = ButtonIconStorage.shared.image(forFilename: value) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(5)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.title = "아이콘 이미지 선택"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ButtonIconStorage.shared.allowedContentTypes
        if panel.runModal() == .OK, let url = panel.url {
            do {
                if !value.isEmpty { ButtonIconStorage.shared.remove(filename: value) }
                value = try ButtonIconStorage.shared.store(sourceURL: url)
            } catch {
                NSSound.beep()
            }
        }
    }
}

// MARK: - Color swatch field

private enum LabelFontPalette {
    // Curated list: macOS-bundled families that render Korean reasonably well plus
    // a few Latin classics. Pretendard/Inter are included because they ship with
    // many user installs; if not present, SwiftUI falls back to the system font.
    static let curated: [String] = [
        "Apple SD Gothic Neo",
        "Pretendard",
        "Helvetica Neue",
        "Avenir Next",
        "Menlo",
        "Georgia",
        "Times New Roman"
    ]
}

private enum ColorPalette {
    static let backgrounds: [String] = [
        "#2C2C2E", "#1F2937", "#111827", "#0F172A",
        "#1E3A8A", "#0F6CBD", "#0E7490", "#065F46",
        "#3F2E7E", "#7C3AED", "#B91C1C", "#C2410C",
        "#D97757", "#F59E0B", "#FFFFFF", "#F5F7FA"
    ]
    static let foregrounds: [String] = [
        "#FFFFFF", "#F3F4F6", "#E5E7EB", "#FBBF24",
        "#FCD34D", "#7DF9C1", "#67E8F9", "#FCA5A5",
        "#222222", "#27364A", "#000000", "#94A3B8"
    ]
}

private struct ColorSwatchField: View {
    let label: String
    @Binding var hex: String
    let fallback: String
    let presets: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label).font(.appFootnoteBold).foregroundStyle(.secondary).frame(width: 32, alignment: .leading)
                swatch(hex: hex.isEmpty ? fallback : hex)
                    .frame(width: 18, height: 18)
                TextField(fallback, text: $hex)
                    .textFieldStyle(.roundedBorder)
                    .font(.appFootnoteMono)
            }
            HStack(spacing: 4) {
                ForEach(presets, id: \.self) { c in
                    Button {
                        hex = c
                    } label: {
                        swatch(hex: c)
                            .frame(width: 16, height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(hex.caseInsensitiveCompare(c) == .orderedSame ? Color.accentColor : Color.black.opacity(0.18), lineWidth: hex.caseInsensitiveCompare(c) == .orderedSame ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(c)
                }
            }
        }
    }

    @ViewBuilder
    private func swatch(hex: String) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.fromHex(hex) ?? .gray)
    }
}

// MARK: - Reusable subviews

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var monospaced: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.appFootnoteBold).foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(monospaced ? .appCalloutMono : .appCallout)
        }
    }
}

private struct ModifierToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isOn ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isOn ? Color.accentColor : Color.clear, lineWidth: 1.2)
                )
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct CodeEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 120
    var maxHeight: CGFloat? = nil
    var flexible: Bool = false
    var monospaced: Bool = true

    var body: some View {
        TextEditor(text: $text)
            .font(monospaced ? .appCalloutMono : .appCallout)
            .scrollContentBackground(.hidden)
            .padding(6)
            .frame(minHeight: minHeight, maxHeight: flexible ? .infinity : maxHeight)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
    }
}
