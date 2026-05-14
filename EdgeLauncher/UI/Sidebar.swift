import SwiftUI
import UniformTypeIdentifiers

struct Sidebar: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter
    @ObservedObject private var badges = BadgeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            TouchScrollContainer {
                VStack(spacing: 6) {
                    ForEach(registry.visibleModules) { module in
                        TouchableTabButton(
                            iconName: module.iconName,
                            title: module.title,
                            isActive: router.activeID == module.id,
                            badgeCount: badges.counts[module.id] ?? 0
                        ) {
                            router.activate(module.id)
                        }
                        .onDrag { NSItemProvider(object: module.id as NSString) }
                        .onDrop(
                            of: [UTType.plainText],
                            delegate: ModuleDropDelegate(targetID: module.id, registry: registry)
                        )
                    }
                }
                .padding(.vertical, 10)
            }

            Spacer()
        }
        .frame(width: 155)
        .background(.regularMaterial)
    }
}

private struct ModuleDropDelegate: DropDelegate {
    let targetID: String
    let registry: ModuleRegistry

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.plainText]).first else { return false }
        provider.loadObject(ofClass: NSString.self) { source, _ in
            guard let sourceID = source as? String else { return }
            DispatchQueue.main.async {
                guard let from = registry.modules.firstIndex(where: { $0.id == sourceID }),
                      let to = registry.modules.firstIndex(where: { $0.id == targetID }) else { return }
                registry.reorder(from: from, to: to)
            }
        }
        return true
    }
}
