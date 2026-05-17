import Combine
import CoreAudio
import SwiftUI

/// macOS 시스템 출력 음량을 읽고/쓴다 (CoreAudio 기반).
/// - 외부에서 음량이 바뀌면 1초 폴링으로 따라잡음.
/// - default output device 가 바뀌어도 다음 refresh 에서 새 device 로 전환.
@MainActor
final class SystemVolumeService: ObservableObject {
    static let shared = SystemVolumeService()

    @Published var volume: Float = 0.5
    @Published var isMuted: Bool = false

    private var pollTimer: Timer?
    private var lastWriteAt: Date = .distantPast

    private init() {
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit {
        pollTimer?.invalidate()
    }

    func setVolume(_ v: Float) {
        let clamped = max(0, min(1, v))
        if abs(clamped - volume) > 0.0001 { volume = clamped }
        lastWriteAt = Date()
        Self.writeSystemVolume(clamped)
        // 음량 0 으로 끌면 mute 도 켬, 0 초과면 mute 해제
        let shouldMute = clamped <= 0.0001
        if shouldMute != isMuted {
            isMuted = shouldMute
            Self.writeMute(shouldMute)
        }
    }

    func toggleMute() {
        let newMute = !isMuted
        isMuted = newMute
        Self.writeMute(newMute)
    }

    private func refresh() {
        // 방금 쓴 직후 0.4s 동안은 외부 변화 ignore (느린 device 의 reflect 지연 대응)
        if Date().timeIntervalSince(lastWriteAt) < 0.4 { return }
        if let v = Self.readSystemVolume(), abs(v - volume) > 0.001 { volume = v }
        if let m = Self.readMute(), m != isMuted { isMuted = m }
    }

    // MARK: - CoreAudio low-level helpers

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil, &size, &deviceID
        )
        return status == noErr && deviceID != 0 ? deviceID : nil
    }

    private static func readSystemVolume() -> Float? {
        guard let device = defaultOutputDevice() else { return nil }
        // 우선 master channel (0), 안 되면 channel 1, 2 평균
        if let v = readVolume(device: device, channel: kAudioObjectPropertyElementMain) {
            return v
        }
        var sum: Float = 0
        var n = 0
        for ch in UInt32(1)...UInt32(2) {
            if let v = readVolume(device: device, channel: ch) { sum += v; n += 1 }
        }
        return n > 0 ? sum / Float(n) : nil
    }

    private static func readVolume(device: AudioDeviceID, channel: UInt32) -> Float? {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )
        guard AudioObjectHasProperty(device, &addr) else { return nil }
        let status = AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &volume)
        return status == noErr ? volume : nil
    }

    private static func writeSystemVolume(_ value: Float) {
        guard let device = defaultOutputDevice() else { return }
        if writeVolume(device: device, channel: kAudioObjectPropertyElementMain, value: value) { return }
        for ch in UInt32(1)...UInt32(2) {
            _ = writeVolume(device: device, channel: ch, value: value)
        }
    }

    @discardableResult
    private static func writeVolume(device: AudioDeviceID, channel: UInt32, value: Float) -> Bool {
        var v = value
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )
        guard AudioObjectHasProperty(device, &addr) else { return false }
        var settable: DarwinBoolean = false
        AudioObjectIsPropertySettable(device, &addr, &settable)
        guard settable.boolValue else { return false }
        let status = AudioObjectSetPropertyData(
            device, &addr, 0, nil,
            UInt32(MemoryLayout<Float32>.size), &v
        )
        return status == noErr
    }

    private static func readMute() -> Bool? {
        guard let device = defaultOutputDevice() else { return nil }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &addr) else { return nil }
        let status = AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &muted)
        return status == noErr ? (muted != 0) : nil
    }

    private static func writeMute(_ muted: Bool) {
        guard let device = defaultOutputDevice() else { return }
        var value: UInt32 = muted ? 1 : 0
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &addr) else { return }
        _ = AudioObjectSetPropertyData(
            device, &addr, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &value
        )
    }
}

/// 상단 상태바 가운데에 표시되는 시스템 음량 슬라이더 (mute 아이콘 클릭 → 토글).
struct SystemVolumeSlider: View {
    @ObservedObject private var service = SystemVolumeService.shared

    private var iconName: String {
        if service.isMuted || service.volume <= 0.0001 { return "speaker.slash.fill" }
        if service.volume < 0.34 { return "speaker.wave.1.fill" }
        if service.volume < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { service.toggleMute() }) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, alignment: .center)
            }
            .buttonStyle(.plain)
            .help(service.isMuted ? "음소거 해제" : "음소거")

            Slider(
                value: Binding(
                    get: { Double(service.volume) },
                    set: { service.setVolume(Float($0)) }
                ),
                in: 0...1
            )
            .controlSize(.small)
            .frame(width: 640)

            Text("\(Int((service.volume * 100).rounded()))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
                .monospacedDigit()
        }
        .help("시스템 음량")
    }
}
