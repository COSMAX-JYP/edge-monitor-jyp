import SwiftUI

struct ActionEditorView: View {
    private enum Metrics {
        static let fontSize: CGFloat = 26
        static let titleFontSize: CGFloat = 40
        static let sectionFontSize: CGFloat = 26
        static let captionFontSize: CGFloat = 22
        static let monospacedFontSize: CGFloat = 28
    }

    let initial: StreamDeckButton
    var onSave: (StreamDeckButton) -> Void
    var onCancel: () -> Void
    var onDelete: () -> Void

    @State private var label: String
    @State private var iconType: IconType
    @State private var iconValue: String
    @State private var backgroundHex: String
    @State private var foregroundHex: String
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
        _iconValue = State(initialValue: initial.icon.value)
        _backgroundHex = State(initialValue: initial.backgroundHex)
        _foregroundHex = State(initialValue: initial.foregroundHex)
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
        VStack(alignment: .leading, spacing: 28) {
            HStack {
                Text("Pad 버튼 편집")
                    .font(.system(size: Metrics.titleFontSize, weight: .semibold))
                Spacer()
                Button("취소") { onCancel() }
                if !isNewButton {
                    Button("삭제", role: .destructive) { onDelete() }
                }
                Button("저장") { saveAndDismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!isValid)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("액션 타입")
                    .font(.system(size: Metrics.sectionFontSize, weight: .semibold))
                Picker("액션 타입", selection: $kind) {
                    ForEach(StreamDeckActionKind.allCases, id: \.self) { k in
                        Label(k.label, systemImage: k.sfSymbol).tag(k)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Group {
                switch kind {
                case .launchApp:
                    LabeledField(label: "Bundle Identifier", placeholder: "예: com.apple.Notes", text: $bundleId)
                case .openURL:
                    LabeledField(label: "URL", placeholder: "https://", text: $urlString)
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

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                Text("표시")
                    .font(.system(size: Metrics.sectionFontSize, weight: .semibold))
                LabeledField(label: "라벨", placeholder: "(옵션)", text: $label)
                HStack(spacing: 24) {
                    Picker("아이콘 타입", selection: $iconType) {
                        Text("SF Symbol").tag(IconType.sfSymbol)
                        Text("이모지").tag(IconType.emoji)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 520)
                    TextField(iconType == .sfSymbol ? "예: bolt.fill" : "예: 🚀", text: $iconValue)
                        .textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 24) {
                    LabeledField(label: "배경 hex", placeholder: "#2C2C2E", text: $backgroundHex)
                    LabeledField(label: "전경 hex", placeholder: "#FFFFFF", text: $foregroundHex)
                }
            }
            Spacer()
        }
        .font(.system(size: Metrics.fontSize))
        .controlSize(.large)
        .padding(40)
        .appSheetFrame(width: 0.55...0.8, height: 0.6...0.85)
    }

    private var keystrokeForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Modifier + Key")
                .font(.system(size: Metrics.sectionFontSize, weight: .semibold))
            HStack(spacing: 24) {
                Toggle("⌘", isOn: $modifierCommand)
                Toggle("⌥", isOn: $modifierOption)
                Toggle("⌃", isOn: $modifierControl)
                Toggle("⇧", isOn: $modifierShift)
                Spacer()
            }
            HStack(spacing: 18) {
                Text("Key")
                    .font(.system(size: Metrics.fontSize))
                TextField("예: a, return, space, f5", text: $keyChar)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)
                Spacer()
            }
            Text("주의: 손쉬운 사용 권한이 필요합니다.")
                .font(.system(size: Metrics.captionFontSize))
                .foregroundStyle(.secondary)
        }
    }

    private var shellForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Shell 명령")
                .font(.system(size: Metrics.sectionFontSize, weight: .semibold))
            TextEditor(text: $shellCommand)
                .font(.system(size: Metrics.monospacedFontSize, design: .monospaced))
                .frame(minHeight: 160, maxHeight: 260)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                )
            HStack {
                Toggle("실행 전 확인", isOn: $shellRequireConfirm)
                Spacer()
                Stepper("타임아웃 \(shellTimeout)초", value: $shellTimeout, in: 1...600)
                    .frame(maxWidth: 420)
            }
            Text("주의: /bin/sh -c 로 실행. 출력은 별도 시트로 표시.")
                .font(.system(size: Metrics.captionFontSize))
                .foregroundStyle(.secondary)
        }
    }

    private var appleScriptForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("AppleScript")
                .font(.system(size: Metrics.sectionFontSize, weight: .semibold))
            TextEditor(text: $appleScriptSource)
                .font(.system(size: Metrics.monospacedFontSize, design: .monospaced))
                .frame(minHeight: 220, maxHeight: 360)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                )
            Toggle("실행 전 확인", isOn: $appleScriptRequireConfirm)
            Text("주의: 대상 앱별 자동화 권한 다이얼로그가 뜰 수 있습니다.")
                .font(.system(size: Metrics.captionFontSize))
                .foregroundStyle(.secondary)
        }
    }

    private var pasteTextForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("붙여넣을 텍스트")
                .font(.system(size: Metrics.sectionFontSize, weight: .semibold))
            TextEditor(text: $pasteText)
                .font(.system(size: Metrics.fontSize))
                .frame(minHeight: 160, maxHeight: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                )
            Toggle("원래 클립보드 복원", isOn: $pasteRestoreClipboard)
            Text("Cmd+V 를 시뮬레이션합니다. 손쉬운 사용 권한 필요.")
                .font(.system(size: Metrics.captionFontSize))
                .foregroundStyle(.secondary)
        }
    }

    private var unsupportedActionForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(kind.label)
                .font(.system(size: Metrics.sectionFontSize, weight: .semibold))
            Text("이 액션 타입의 편집 UI는 아직 준비 중입니다.")
                .font(.system(size: Metrics.captionFontSize))
                .foregroundStyle(.secondary)
        }
    }

    private var isNewButton: Bool {
        if case .none = initial.action, initial.label.isEmpty { return true }
        return false
    }

    private var isValid: Bool {
        switch kind {
        case .launchApp: return !bundleId.trimmingCharacters(in: .whitespaces).isEmpty
        case .openURL: return URL(string: urlString.trimmingCharacters(in: .whitespaces)) != nil
        case .keystroke: return !keyChar.trimmingCharacters(in: .whitespaces).isEmpty
        case .shell: return !shellCommand.trimmingCharacters(in: .whitespaces).isEmpty
        case .appleScript: return !appleScriptSource.trimmingCharacters(in: .whitespaces).isEmpty
        case .pasteText: return !pasteText.isEmpty
        case .webhook, .aiPrompt, .multi: return false
        }
    }

    private func saveAndDismiss() {
        var btn = initial
        btn.label = label
        btn.icon = IconSpec(type: iconType, value: iconValue)
        btn.backgroundHex = backgroundHex.isEmpty ? "#2C2C2E" : backgroundHex
        btn.foregroundHex = foregroundHex.isEmpty ? "#FFFFFF" : foregroundHex
        switch kind {
        case .launchApp:
            btn.action = .launchApp(bundleId: bundleId.trimmingCharacters(in: .whitespaces))
        case .openURL:
            btn.action = .openURL(url: urlString.trimmingCharacters(in: .whitespaces))
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
            return
        }
        btn.updatedAt = Date()
        onSave(btn)
    }
}

private struct LabeledField: View {
    private enum Metrics {
        static let fontSize: CGFloat = 26
        static let labelFontSize: CGFloat = 22
    }

    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: Metrics.labelFontSize))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: Metrics.fontSize))
        }
    }
}
