import SwiftUI

struct WebhookTemplatePicker: View {
    var onPick: (WebhookTemplate) -> Void

    var body: some View {
        Menu {
            ForEach(WebhookTemplate.presets, id: \.id) { template in
                Button {
                    onPick(template)
                } label: {
                    Label(template.name, systemImage: template.iconSymbol)
                }
            }
        } label: {
            Label("프리셋 적용", systemImage: "rectangle.stack.badge.plus")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
