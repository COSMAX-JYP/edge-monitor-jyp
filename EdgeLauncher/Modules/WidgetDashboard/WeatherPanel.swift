import SwiftUI

struct WeatherPanel: View {
    @ObservedObject var weather: WeatherService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !weather.hasLocationAccess {
                weatherPermission
            } else if weather.snapshot.weatherCode < 0 {
                ProgressView("로딩 중...").controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                weatherBody
            }
            Spacer()
            if let err = weather.errorMessage {
                Text(err).font(.system(size: 10)).foregroundStyle(.red)
            }
            Text("Open-Meteo + Apple CoreLocation")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            Label("날씨", systemImage: "cloud.sun.fill")
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.multicolor)
            Spacer()
            if let updated = weather.lastUpdated {
                Text(relativeUpdate(updated))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var weatherBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(weather.snapshot.locationName.isEmpty ? "현재 위치" : weather.snapshot.locationName)
                .font(.system(size: 12)).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Image(systemName: weather.snapshot.icon).font(.system(size: 56)).symbolRenderingMode(.multicolor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.0f°", weather.snapshot.temperature))
                        .font(.system(size: 48, weight: .ultraLight)).monospacedDigit()
                    Text(weather.snapshot.description).font(.system(size: 14)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            VStack(spacing: 6) {
                weatherStat(icon: "thermometer.medium", label: "체감", value: String(format: "%.0f°", weather.snapshot.feelsLike))
                weatherStat(icon: "humidity.fill", label: "습도", value: "\(weather.snapshot.humidity)%")
                weatherStat(icon: "wind", label: "바람", value: String(format: "%.1f m/s", weather.snapshot.windSpeed))
                weatherStat(icon: "sun.max.fill", label: "UV", value: String(format: "%.1f", weather.snapshot.uvIndex))
            }
        }
    }

    private var weatherPermission: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("위치 권한이 필요합니다", systemImage: "location.slash")
                .font(.system(size: 13, weight: .semibold))
            Text("시스템 설정 > 개인정보 보호 및 보안 > 위치 서비스에서 EdgeLauncher 허용.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Button("다시 시도") { weather.start() }.controlSize(.small)
        }
        .padding(10)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func weatherStat(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 18)
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium, design: .monospaced)).monospacedDigit()
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private func relativeUpdate(_ d: Date) -> String {
        let sec = Int(-d.timeIntervalSinceNow)
        return sec < 60 ? "\(sec)초 전" : "\(sec / 60)분 전"
    }
}
