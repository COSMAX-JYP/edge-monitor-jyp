import SwiftUI

struct ModuleVisibilityView: View {
    @EnvironmentObject var registry: ModuleRegistry

    private let columns = [
        GridItem(.adaptive(minimum: 180), spacing: 12, alignment: .leading)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("표시할 탭")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(registry.modules) { module in
                        moduleTile(module: module)
                    }
                }

                if registry.hiddenIDs.count == registry.modules.count {
                    Label("모든 탭이 숨겨졌습니다. 적어도 하나 표시 권장.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                }
            }
            .padding(24)
        }
    }

    private func moduleTile(module: AnyEdgeModule) -> some View {
        let isVisible = !registry.hiddenIDs.contains(module.id)
        return Button {
            registry.setVisible(module.id, visible: !isVisible)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isVisible ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isVisible ? Color.accentColor : Color.secondary)
                    .font(.system(size: 16, weight: .medium))
                Image(systemName: module.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 22)
                    .foregroundStyle(isVisible ? Color.primary : Color.secondary)
                Text(module.title)
                    .font(.body)
                    .foregroundStyle(isVisible ? Color.primary : Color.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isVisible ? Color.primary.opacity(0.06) : Color.primary.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
