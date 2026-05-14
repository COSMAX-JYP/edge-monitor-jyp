import Combine
import EventKit
import SwiftUI

struct WidgetDashboardView: View {
    @State private var now = Date()
    @StateObject private var eventVM = EventStoreVM()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            topRow
            Divider()
            HStack(spacing: 0) {
                weatherPanel
                Divider()
                outlookPanel
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(timer) { now = $0 }
        .task { await eventVM.requestAccess() }
    }

    // MARK: - 상단 시계 + 날짜

    private var topRow: some View {
        HStack(spacing: 36) {
            Text(timeText)
                .font(.system(size: 110, weight: .ultraLight, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(LinearGradient(
                    colors: [Color.primary, Color.primary.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                ))

            VStack(alignment: .leading, spacing: 6) {
                Text(dateText)
                    .font(.system(size: 32, weight: .regular, design: .rounded))
                Text(dayText)
                    .font(.system(size: 22, weight: .light, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Label(weekProgress, systemImage: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text("\(dayOfYear)일째 / 365일")
                    .font(.system(size: 12, weight: .light, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.08), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: - 날씨 패널

    private var weatherPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                Label("날씨", systemImage: "cloud.sun.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.multicolor)
                Spacer()
                Text("서울시 강남구")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 84))
                    .symbolRenderingMode(.multicolor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("--°")
                        .font(.system(size: 72, weight: .ultraLight))
                        .monospacedDigit()
                    Text("연동 예정")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 18) {
                weatherStat(icon: "thermometer.medium", label: "체감", value: "--°")
                weatherStat(icon: "humidity.fill", label: "습도", value: "--%")
                weatherStat(icon: "wind", label: "바람", value: "-- m/s")
                weatherStat(icon: "sun.max.fill", label: "UV", value: "--")
            }

            HStack(spacing: 12) {
                ForEach(0..<6) { i in
                    forecastCell(hourOffset: i)
                }
            }
            .padding(.top, 4)

            Spacer()

            Text("WeatherKit 연동 예정 — 실제 위치/온도/예보 표시")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func weatherStat(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.background.opacity(0.5))
        .cornerRadius(10)
    }

    private func forecastCell(hourOffset: Int) -> some View {
        let hour = (Calendar.current.component(.hour, from: now) + hourOffset) % 24
        let label = String(format: "%02d시", hour)
        return VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Image(systemName: ["sun.max.fill", "cloud.sun.fill", "cloud.fill"][hourOffset % 3])
                .font(.system(size: 22))
                .symbolRenderingMode(.multicolor)
            Text("--°")
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.background.opacity(0.3))
        .cornerRadius(8)
    }

    // MARK: - Outlook (macOS Calendar) 패널

    private var outlookPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("오늘 일정", systemImage: "calendar")
                    .font(.system(size: 22, weight: .semibold))
                Spacer()
                if eventVM.hasAccess {
                    Text("\(eventVM.events.count)건")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Button(action: { eventVM.reload() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("새로고침")
            }

            if !eventVM.hasAccess {
                permissionBanner
            } else if eventVM.events.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(eventVM.events, id: \.eventIdentifier) { event in
                            eventRow(event)
                        }
                    }
                }
            }

            Spacer()

            Text("macOS Calendar에 연결된 Outlook 일정도 함께 표시됩니다.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func eventRow(_ event: EKEvent) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(cgColor: event.calendar?.cgColor ?? CGColor(red: 0.4, green: 0.6, blue: 1, alpha: 1)))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "(제목 없음)")
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(timeRange(event))
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if let location = event.location, !location.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if let cal = event.calendar {
                    Text(cal.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.background.opacity(0.5))
        .cornerRadius(8)
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("캘린더 권한이 필요합니다", systemImage: "lock.fill")
                .font(.system(size: 16, weight: .semibold))
            Text("시스템 설정 > 개인정보 보호 및 보안 > 캘린더에서 EdgeLauncher 를 켜주세요.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Button("권한 다시 요청") {
                Task { await eventVM.requestAccess() }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.yellow.opacity(0.12))
        .cornerRadius(10)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("오늘 일정이 없습니다")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private func timeRange(_ event: EKEvent) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        if event.isAllDay { return "종일" }
        return "\(f.string(from: event.startDate)) – \(f.string(from: event.endDate))"
    }

    // MARK: - 시간/날짜 포맷

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: now)
    }

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일"
        return f.string(from: now)
    }

    private var dayText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "EEEE"
        return f.string(from: now)
    }

    private var weekProgress: String {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now)
        let mondayBased = ((weekday + 5) % 7) + 1
        return "이번 주 \(mondayBased)/7일"
    }

    private var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0
    }
}
