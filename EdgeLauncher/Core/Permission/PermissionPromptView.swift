import SwiftUI

struct PermissionPromptView: View {
    let kind: PermissionKind
    let state: PermissionState
    let title: String
    let detail: String
    var requestAction: () async -> Void
    var openSettings: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: iconName)
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text(title).font(.appTitle)
            Text(detail)
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
            actionButton
        }
        .padding(36)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .notDetermined, .unknown:
            Button("허용") {
                Task { await requestAction() }
            }
            .font(.appBodyBold)
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        case .denied, .restricted:
            Button("시스템 설정 열기") { openSettings() }
                .font(.appBodyBold)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
        case .writeOnly:
            VStack(spacing: 8) {
                Text("쓰기 전용 권한입니다").font(.appCallout).foregroundStyle(.secondary)
                Button("시스템 설정 열기") { openSettings() }
                    .font(.appBody)
                    .buttonStyle(.bordered)
            }
        case .authorized:
            Label("권한 허용됨", systemImage: "checkmark.circle.fill")
                .font(.appBody)
                .foregroundStyle(.green)
        }
    }

    private var iconName: String {
        switch kind {
        case .calendar: return "calendar"
        case .accessibility: return "accessibility"
        case .automation: return "gearshape.2"
        case .msal: return "person.crop.circle.badge.checkmark"
        }
    }
}
