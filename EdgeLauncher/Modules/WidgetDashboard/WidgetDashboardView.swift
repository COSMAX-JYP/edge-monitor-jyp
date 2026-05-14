import Combine
import SwiftUI

struct WidgetDashboardView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            clockPanel
            Divider()
            weatherPanel
            Divider()
            calendarPanel
            Divider()
            todoPanel
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(timer) { now = $0 }
    }

    private var clockPanel: some View {
        VStack(spacing: 8) {
            Text(timeText)
                .font(.system(size: 88, weight: .light, design: .monospaced))
                .monospacedDigit()
            Text(dateText)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var weatherPanel: some View {
        VStack(spacing: 10) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 56))
                .symbolRenderingMode(.multicolor)
            Text("--°")
                .font(.system(size: 44, weight: .light, design: .rounded))
            Text("날씨 API 연동 예정")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var calendarPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("오늘 일정", systemImage: "calendar")
                .font(.system(size: 14, weight: .semibold))
                .padding(.bottom, 4)
            placeholderRow("09:30 standup")
            placeholderRow("13:00 design review")
            placeholderRow("16:00 1:1")
            Text("EventKit 연동 예정")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var todoPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("할일", systemImage: "checklist")
                .font(.system(size: 14, weight: .semibold))
                .padding(.bottom, 4)
            placeholderRow("☐ Phase 2 모듈 검수")
            placeholderRow("☐ 디자인 spec follow-up")
            placeholderRow("☐ 위젯 데이터 소스 정하기")
            Text("Reminders 연동 예정")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func placeholderRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
    }

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: now)
    }

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f.string(from: now)
    }
}
