import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct LauncherView: View {
    @StateObject private var store = LauncherStore()
    @State private var editMode = false
    @StateObject private var iconCache = LauncherIconCache()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 24), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 28) {
                    ForEach(store.entries) { entry in
                        appCell(entry)
                    }
                    if editMode {
                        addCell
                    }
                }
                .padding(32)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack {
            Label("Launcher", systemImage: "square.grid.3x3.fill")
                .font(.appBodyBold)
            Spacer()
            Text("\(store.entries.count)개")
                .font(.appFootnoteMono)
                .foregroundStyle(.secondary)
            Button(action: { editMode.toggle() }) {
                Label(editMode ? "완료" : "편집", systemImage: editMode ? "checkmark" : "pencil")
                    .font(.appFootnoteBold)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func appCell(_ entry: LauncherEntry) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Button(action: { handleClick(entry) }) {
                    Image(nsImage: iconCache.icon(for: entry.bundleURL))
                        .resizable()
                        .frame(width: 108, height: 108)
                }
                .buttonStyle(.plain)
                .disabled(editMode)

                if editMode {
                    Button(action: { store.remove(entry) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, .red)
                            .background(Circle().fill(.background))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 8, y: -8)
                }
            }
            Text(entry.name)
                .font(.appFootnote)
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
    }

    private var addCell: some View {
        VStack(spacing: 10) {
            Button(action: addApp) {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .frame(width: 108, height: 108)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.secondary)
                    )
            }
            .buttonStyle(.plain)
            Text("앱 추가")
                .font(.appFootnote)
                .foregroundStyle(.secondary)
        }
    }

    private func handleClick(_ entry: LauncherEntry) {
        store.launch(entry)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.title = "런처에 추가할 앱 선택"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            for url in panel.urls {
                store.add(url: url)
            }
        }
    }
}

@MainActor
private final class LauncherIconCache: ObservableObject {
    private var icons: [String: NSImage] = [:]

    func icon(for path: String) -> NSImage {
        if let cached = icons[path] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icons[path] = icon
        return icon
    }
}
