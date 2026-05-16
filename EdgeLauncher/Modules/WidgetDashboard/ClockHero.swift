import Combine
import Foundation
import IOKit.ps
import SwiftUI

struct ClockHero: View {
    let now: Date
    @AppStorage("app.themeMode") private var themeMode = "dark"
    @StateObject private var battery = ClockBatteryMonitor()

    var body: some View {
        let palette = ClockHeroPalette(isLight: isLightTheme)
        ZStack {
            palette.background

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.panel)
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 20)

            HStack(spacing: 30) {
                flipClock(palette: palette)

                VStack(alignment: .leading, spacing: 10) {
                    Text(dateText)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.primary)
                    Text(dayText)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondary)

                    HStack(spacing: 10) {
                        statPill(label: "주", value: weekProgress, palette: palette)
                        statPill(label: "연", value: "\(dayOfYear)/365", palette: palette)
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 24)

                HStack(spacing: 22) {
                    batteryRing(
                        title: "MacBook",
                        systemImage: "laptopcomputer",
                        percent: battery.macBookPercent,
                        palette: palette
                    )
                    batteryRing(
                        title: "AirPods",
                        systemImage: "airpodspro",
                        percent: battery.airPodsPercent,
                        palette: palette
                    )
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(height: 220)
        .onAppear { battery.start() }
        .onDisappear { battery.stop() }
    }

    private var isLightTheme: Bool {
        themeMode == "light"
    }

    private func flipClock(palette: ClockHeroPalette) -> some View {
        HStack(spacing: 12) {
            flipUnit(hourText, palette: palette)
            flipUnit(minuteText, palette: palette)
            flipUnit(secondText, palette: palette)
        }
    }

    private func flipUnit(_ value: String, palette: ClockHeroPalette) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.flipTop)
            VStack(spacing: 0) {
                palette.flipTop
                palette.flipBottom
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            Rectangle()
                .fill(palette.flipDivider)
                .frame(height: 1)
            Text(value)
                .font(.system(size: 78, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.time)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 148, height: 118)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1.2)
        )
        .shadow(color: palette.shadow, radius: 22, x: 0, y: 14)
    }

    private func batteryRing(title: String, systemImage: String, percent: Int?, palette: ClockHeroPalette) -> some View {
        let value = max(0, min(percent ?? 0, 100))
        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(palette.ringTrack, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(value) / 100)
                    .stroke(
                        palette.ring,
                        style: StrokeStyle(lineWidth: 14, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-120))
                VStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                    Text(percent.map { "\($0)%" } ?? "--")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(palette.ringText)
            }
            .frame(width: 108, height: 108)
            .shadow(color: palette.ringShadow, radius: 18)
            Text(title)
                .font(.appFootnoteBold)
                .foregroundStyle(palette.secondary)
        }
        .frame(width: 124)
    }

    private func statPill(label: String, value: String, palette: ClockHeroPalette) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.appFootnoteBold).foregroundStyle(palette.secondary)
            Text(value).font(.appFootnoteMono).foregroundStyle(palette.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(palette.pill, in: Capsule())
    }

    private var timeText: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: now)
    }
    private var hourText: String {
        let f = DateFormatter(); f.dateFormat = "HH"; return f.string(from: now)
    }
    private var minuteText: String {
        let f = DateFormatter(); f.dateFormat = "mm"; return f.string(from: now)
    }
    private var secondText: String {
        let f = DateFormatter(); f.dateFormat = "ss"; return f.string(from: now)
    }
    private var dateText: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "yyyy년 M월 d일"; return f.string(from: now)
    }
    private var dayText: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "EEEE"; return f.string(from: now)
    }
    private var weekProgress: String {
        let wd = Calendar.current.component(.weekday, from: now)
        let mb = ((wd + 5) % 7) + 1
        return "\(mb)/7"
    }
    private var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0
    }
}

private struct ClockHeroPalette {
    let isLight: Bool

    var background: LinearGradient {
        if isLight {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.98, blue: 1.00),
                    Color(red: 0.90, green: 0.95, blue: 0.98),
                    Color(red: 0.98, green: 0.99, blue: 1.00)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.13),
                    Color(red: 0.11, green: 0.14, blue: 0.20),
                    Color(red: 0.04, green: 0.12, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var panel: Color { isLight ? Color.white.opacity(0.72) : Color.white.opacity(0.045) }
    var border: Color { isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.14) }
    var primary: Color { isLight ? Color(red: 0.10, green: 0.15, blue: 0.24) : Color.white.opacity(0.92) }
    var secondary: Color { isLight ? Color(red: 0.36, green: 0.43, blue: 0.54) : Color.white.opacity(0.64) }
    var time: Color { isLight ? Color(red: 0.08, green: 0.11, blue: 0.18) : Color(red: 0.96, green: 0.97, blue: 1.00) }
    var pill: Color { isLight ? Color.black.opacity(0.055) : Color.white.opacity(0.10) }
    var flipTop: Color { isLight ? Color(red: 0.95, green: 0.97, blue: 1.00) : Color(red: 0.13, green: 0.16, blue: 0.22) }
    var flipBottom: Color { isLight ? Color(red: 0.89, green: 0.92, blue: 0.97) : Color(red: 0.09, green: 0.12, blue: 0.17) }
    var flipDivider: Color { isLight ? Color.black.opacity(0.18) : Color.black.opacity(0.72) }
    var shadow: Color { isLight ? Color.black.opacity(0.11) : Color.black.opacity(0.30) }
    var ringTrack: Color { isLight ? Color.black.opacity(0.10) : Color.white.opacity(0.15) }
    var ring: Color { isLight ? Color(red: 0.06, green: 0.69, blue: 0.56) : Color(red: 0.43, green: 0.88, blue: 0.66) }
    var ringText: Color { isLight ? Color(red: 0.05, green: 0.27, blue: 0.23) : Color(red: 0.82, green: 1.00, blue: 0.93) }
    var ringShadow: Color { isLight ? Color(red: 0.06, green: 0.69, blue: 0.56).opacity(0.18) : Color(red: 0.43, green: 0.88, blue: 0.66).opacity(0.24) }
}

@MainActor
private final class ClockBatteryMonitor: ObservableObject {
    @Published var macBookPercent: Int?
    @Published var airPodsPercent: Int?

    private var timer: Timer?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        macBookPercent = Self.readMacBookBattery()
        Task {
            airPodsPercent = await Self.readAirPodsBattery()
        }
    }

    private static func readMacBookBattery() -> Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let current = description[kIOPSCurrentCapacityKey as String] as? Int,
                  let max = description[kIOPSMaxCapacityKey as String] as? Int,
                  max > 0 else {
                continue
            }
            return Int((Double(current) / Double(max) * 100).rounded())
        }
        return nil
    }

    private static func readAirPodsBattery() async -> Int? {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
            process.arguments = ["-r", "-l", "-k", "BatteryPercent"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8),
                      output.localizedCaseInsensitiveContains("AirPods") else {
                    return nil
                }
                return parseAirPodsPercent(from: output)
            } catch {
                return nil
            }
        }.value
    }

    private nonisolated static func parseAirPodsPercent(from output: String) -> Int? {
        let blocks = output.components(separatedBy: "+-o ")
        for block in blocks where block.localizedCaseInsensitiveContains("AirPods") {
            let matches = block.matches(for: #""BatteryPercent(?:Left|Right|Case)?" = (\d+)"#)
            let values = matches.compactMap(Int.init)
            if !values.isEmpty {
                return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
            }
        }
        return nil
    }
}

private extension String {
    nonisolated func matches(for pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..., in: self)
        return regex.matches(in: self, range: range).compactMap { result in
            guard result.numberOfRanges > 1,
                  let range = Range(result.range(at: 1), in: self) else {
                return nil
            }
            return String(self[range])
        }
    }
}
