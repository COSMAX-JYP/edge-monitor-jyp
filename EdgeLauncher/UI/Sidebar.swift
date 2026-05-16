import SwiftUI
import UniformTypeIdentifiers

struct Sidebar: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter
    @ObservedObject private var badges = BadgeStore.shared
    @AppStorage("app.themeMode") private var themeMode = "dark"

    @State private var draggingID: String?
    @State private var isEditing: Bool = false
    @State private var selectedSlotID: String?

    private let columns = [
        GridItem(.fixed(EdgeTheme.tabTileWidth), spacing: 4),
        GridItem(.fixed(EdgeTheme.tabTileWidth), spacing: 4),
        GridItem(.fixed(EdgeTheme.tabTileWidth), spacing: 4),
        GridItem(.fixed(EdgeTheme.tabTileWidth), spacing: 4),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            TouchScrollContainer {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(registry.visibleSlots) { slot in
                        slotView(slot: slot)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .frame(width: EdgeTheme.sidebarWidth)
            }

            Spacer()
        }
        .frame(width: EdgeTheme.sidebarWidth)
        .background(
            EdgeTheme.railFill(isLight: isLightTheme)
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(EdgeTheme.stroke(isLight: isLightTheme))
                .frame(width: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label("APPS", systemImage: "square.grid.2x2.fill")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            if isEditing {
                Button {
                    registry.appendEmptySlot()
                } label: {
                    Image(systemName: "plus.rectangle.on.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 44, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: EdgeTheme.controlRadius)
                                .fill(EdgeTheme.elevatedFill(isLight: isLightTheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: EdgeTheme.controlRadius)
                                .stroke(EdgeTheme.stroke(isLight: isLightTheme), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("빈 칸 추가")
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isEditing.toggle()
                    if !isEditing { selectedSlotID = nil }
                }
            } label: {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: EdgeTheme.controlRadius)
                            .fill(isEditing ? EdgeTheme.cyan.opacity(0.95) : EdgeTheme.elevatedFill(isLight: isLightTheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EdgeTheme.controlRadius)
                            .stroke(isEditing ? Color.white.opacity(0.45) : EdgeTheme.stroke(isLight: isLightTheme), lineWidth: 1)
                    )
                    .foregroundStyle(isEditing ? Color.black.opacity(0.86) : Color.primary)
            }
            .buttonStyle(.plain)
            .help(isEditing ? "편집 완료" : "탭 편집")
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func slotView(slot: SidebarSlot) -> some View {
        let isSelected = selectedSlotID == slot.id
        switch slot {
        case .module(let moduleID):
            if let module = registry.module(id: moduleID) {
                TouchableTabButton(
                    iconName: module.iconName,
                    title: module.title,
                    isActive: !isEditing && router.activeID == module.id,
                    badgeCount: isEditing ? 0 : (badges.counts[module.id] ?? 0),
                    customIcon: module.iconCustomization
                ) {
                    if isEditing {
                        handleEditTap(slotID: slot.id)
                    } else {
                        router.activate(module.id)
                    }
                }
                .overlay(selectionOverlay(isSelected: isSelected))
                .opacity(draggingID == module.id ? 0.4 : 1)
                .scaleEffect(isSelected ? 0.96 : 1)
                .contextMenu { reorderMenu(for: module.id) }
                .onDrag {
                    draggingID = module.id
                    return NSItemProvider(object: module.id as NSString)
                }
                .onDrop(of: [UTType.text], delegate: ReorderDropDelegate(
                    targetID: module.id,
                    registry: registry,
                    draggingID: $draggingID
                ))
            }
        case .empty:
            emptySlotView(slotID: slot.id, isSelected: isSelected)
        }
    }

    private func emptySlotView(slotID: String, isSelected: Bool) -> some View {
        Button {
            if isEditing { handleEditTap(slotID: slotID) }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: isEditing ? "square.dashed" : "")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 82, height: 62)
                if isEditing {
                    Text("빈 칸")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: EdgeTheme.tabTileWidth, height: EdgeTheme.tabTileHeight)
            .background(
                RoundedRectangle(cornerRadius: EdgeTheme.controlRadius)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(isEditing ? Color.secondary.opacity(0.4) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(selectionOverlay(isSelected: isSelected))
        .contextMenu {
            if isEditing {
                Button(role: .destructive) {
                    registry.removeSlot(slotID: slotID)
                } label: {
                    Label("이 빈 칸 제거", systemImage: "trash")
                }
            }
        }
    }

    private func selectionOverlay(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: EdgeTheme.controlRadius + 2)
            .stroke(isSelected ? EdgeTheme.amber : Color.clear, lineWidth: 2)
            .padding(1)
    }

    private var isLightTheme: Bool {
        themeMode == "light"
    }

    private func handleEditTap(slotID: String) {
        if let selected = selectedSlotID {
            if selected == slotID {
                selectedSlotID = nil
                return
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                registry.swapSlots(slotIDA: selected, slotIDB: slotID)
            }
            selectedSlotID = nil
        } else {
            selectedSlotID = slotID
        }
    }

    @ViewBuilder
    private func reorderMenu(for id: String) -> some View {
        if let idx = registry.modules.firstIndex(where: { $0.id == id }) {
            let lastIdx = registry.modules.count - 1
            Button("위로 이동") { registry.reorder(from: idx, to: idx - 1) }
                .disabled(idx == 0)
            Button("아래로 이동") { registry.reorder(from: idx, to: idx + 1) }
                .disabled(idx >= lastIdx)
            Divider()
            Button("맨 위로") { registry.reorder(from: idx, to: 0) }
                .disabled(idx == 0)
            Button("맨 아래로") { registry.reorder(from: idx, to: lastIdx) }
                .disabled(idx >= lastIdx)
            Divider()
            Button("이 탭 숨기기") { registry.setVisible(id, visible: false) }
        }
    }
}

private struct ReorderDropDelegate: DropDelegate {
    let targetID: String
    let registry: ModuleRegistry
    @Binding var draggingID: String?

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        guard let sourceID = draggingID, sourceID != targetID else { return }
        guard let from = registry.modules.firstIndex(where: { $0.id == sourceID }),
              let to = registry.modules.firstIndex(where: { $0.id == targetID }) else { return }
        if from != to {
            withAnimation(.easeInOut(duration: 0.15)) {
                registry.reorder(from: from, to: to)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
