import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ModuleIconEditorSheet: View {
    let moduleID: String
    let title: String
    let systemIconName: String
    let initialCustomization: IconCustomization?
    var onClose: () -> Void

    @State private var imagePath: String = ""
    @State private var imageScale: Double = 1.0
    @State private var imageOffsetX: Double = 0
    @State private var imageOffsetY: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("\(title) 아이콘 변경")
                    .font(.appTitle)
                Spacer()
                Button("닫기", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }

            HStack(alignment: .top, spacing: 18) {
                preview

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Button {
                            pickImage()
                        } label: {
                            Label("이미지 선택", systemImage: "photo.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(role: .destructive) {
                            clearImage()
                        } label: {
                            Label("기본 아이콘", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(imagePath.isEmpty)
                    }

                    Text(imagePath.isEmpty ? "이미지를 선택하면 사이드바 앱 아이콘이 해당 이미지로 표시됩니다." : URL(fileURLWithPath: imagePath).lastPathComponent)
                        .font(.appCallout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if !imagePath.isEmpty {
                        adjustmentControls
                    }
                }
            }
        }
        .padding(22)
        .frame(width: 620)
        .onAppear(perform: load)
    }

    private var preview: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 126, height: 96)
                if !imagePath.isEmpty, let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(imageScale)
                        .offset(x: imageOffsetX, y: imageOffsetY)
                        .frame(width: 126, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Image(systemName: systemIconName)
                        .font(.system(size: 52, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
            }
            Text("미리보기")
                .font(.appFootnote)
                .foregroundStyle(.secondary)
        }
    }

    private var adjustmentControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            sliderRow(title: "크기", value: $imageScale, range: 0.5...2.0, step: 0.05, text: String(format: "%.2fx", imageScale))
            sliderRow(title: "좌우", value: $imageOffsetX, range: -30...30, step: 1, text: "\(Int(imageOffsetX))")
            sliderRow(title: "상하", value: $imageOffsetY, range: -30...30, step: 1, text: "\(Int(imageOffsetY))")
        }
        .onChange(of: imageScale) { _, _ in commit() }
        .onChange(of: imageOffsetX) { _, _ in commit() }
        .onChange(of: imageOffsetY) { _, _ in commit() }
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, text: String) -> some View {
        HStack {
            Text(title)
                .font(.appCallout)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(text)
                .font(.appCalloutMono)
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
    }

    private func load() {
        if let current = ModuleIconCustomizationStore.customization(for: moduleID) ?? initialCustomization {
            imagePath = current.imagePath
            imageScale = current.scale
            imageOffsetX = current.offsetX
            imageOffsetY = current.offsetY
        }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif, .tiff, .image]
        panel.prompt = "선택"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let dest = try IconStorage.install(sourceURL: url, moduleID: moduleID)
                imagePath = dest.path
                imageScale = 1.0
                imageOffsetX = 0
                imageOffsetY = 0
                commit()
            } catch {
                NSSound.beep()
            }
        }
    }

    private func clearImage() {
        ModuleIconCustomizationStore.clear(for: moduleID)
        imagePath = ""
        imageScale = 1.0
        imageOffsetX = 0
        imageOffsetY = 0
    }

    private func commit() {
        guard !imagePath.isEmpty else { return }
        ModuleIconCustomizationStore.save(
            IconCustomization(imagePath: imagePath, scale: imageScale, offsetX: imageOffsetX, offsetY: imageOffsetY),
            for: moduleID
        )
    }
}
