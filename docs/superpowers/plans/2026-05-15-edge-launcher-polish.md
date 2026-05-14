# EdgeLauncher Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** EdgeLauncher의 성능·메모리·UX·신뢰성을 정리한다. 모듈 lifecycle 훅 도입, WKWebView lazy load, 사이드바 터치 스크롤, 키보드 단축키, 모듈 순서/표시 토글, 풀스크린 chrome 자동 숨김, 통합 에러 배너·로깅, 그리고 Phase 2 모듈 테스트.

**Architecture:** EdgeModule 프로토콜에 옵션 lifecycle 메서드 추가. RootView가 활성화된 모듈만 ZStack에 등록(lazy load). 모듈은 활성/비활성 시 자신의 Timer를 stop/start. 사이드바는 NSScrollView wrapper(NSTouchTypeDirect)로 손가락 panning 지원.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, WebKit, EventKit, CoreLocation, os.Logger, XCTest. 기존 macOS 14+ 타깃 유지.

**Spec:** `docs/superpowers/specs/2026-05-15-edge-launcher-polish-design.md`

---

## File Structure

신규 / 변경 / 삭제 파일 매핑.

```
EdgeLauncher/
├── Core/
│   ├── Log/
│   │   └── AppLog.swift                          # 신규
│   ├── Touch/
│   │   ├── TouchScrollContainer.swift            # 신규
│   │   └── TouchPanGestureInstaller.swift        # 신규
│   ├── Module/
│   │   ├── EdgeModule.swift                      # 수정: lifecycle 메서드 옵션 추가
│   │   └── ModuleRegistry.swift                  # 수정: reorder, visibleIDs, lifecycle forwarding
│   ├── Window/
│   │   └── ChromeVisibilityController.swift      # 신규: 풀스크린 mouse-idle 감지
│   └── Error/
│       ├── ErrorBus.swift                        # 신규
│       └── ErrorBanner.swift                     # 신규
├── UI/
│   ├── RootView.swift                            # 수정: lazy load, chrome 숨김, ErrorBanner
│   ├── Sidebar.swift                             # 수정: TouchScrollContainer 적용, drag&drop
│   └── TabRouter.swift                           # 수정: lifecycle 콜백 호출
├── App/
│   ├── AppEnvironment.swift                      # 수정: visibleIDs/order 복원
│   └── EdgeLauncherApp.swift                     # 수정: 단축키 메뉴 커맨드
├── Settings/
│   ├── SettingsView.swift                        # 수정: 일반 탭 그대로, 탭 탭은 ModuleVisibilityView로 분리
│   └── ModuleVisibilityView.swift                # 신규
├── Modules/
│   ├── WidgetDashboard/
│   │   ├── WidgetDashboardView.swift             # 수정: 컨테이너만 (70줄 이하)
│   │   ├── ClockHero.swift                       # 신규
│   │   ├── WeatherPanel.swift                    # 신규
│   │   ├── OutlookPanel.swift                    # 신규
│   │   ├── RemindersPanel.swift                  # 신규
│   │   ├── WeatherService.swift                  # 수정: AppLog, lifecycle stop
│   │   └── EventStoreVM.swift                    # 수정: AppLog
│   ├── SystemMonitor/
│   │   ├── SystemMonitorView.swift               # 수정: 컨테이너만 (120줄 이하)
│   │   ├── Sparkline.swift                       # 신규
│   │   ├── ProcessColumn.swift                   # 신규
│   │   ├── SystemMonitorModule.swift             # 수정: lifecycle
│   │   ├── SystemStats.swift                     # 수정: stop/start
│   │   └── ProcessStats.swift                    # 수정: stop/start
│   ├── Messenger/
│   │   └── MessengerView.swift                   # 수정: parseUnread를 internal로 (테스트 가능)
│   ├── Launcher/
│   │   └── LauncherStore.swift                   # 수정: AppLog
│   ├── Ambient/                                  # 삭제
│   └── (NowPlayingBridge 삭제)
└── EdgeLauncherTests/
    ├── EdgeModuleLifecycleTests.swift            # 신규
    ├── ModuleRegistryReorderTests.swift          # 신규
    ├── DiscordParseUnreadTests.swift             # 신규
    ├── LauncherStoreTests.swift                  # 신규
    └── Phase2ModuleMetadataTests.swift           # 신규
```

---

## Task 1: AppLog 통합 로깅

**Files:**
- Create: `EdgeLauncher/Core/Log/AppLog.swift`

- [ ] **Step 1: 구현**

```swift
import Foundation
import os

enum AppLog {
    private static let subsystem = "com.jongyoungpark.edgelauncher"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let weather = Logger(subsystem: subsystem, category: "weather")
    static let event = Logger(subsystem: subsystem, category: "event")
    static let launcher = Logger(subsystem: subsystem, category: "launcher")
    static let monitor = Logger(subsystem: subsystem, category: "monitor")
    static let web = Logger(subsystem: subsystem, category: "web")
}
```

- [ ] **Step 2: 빌드 검증**

`bash scripts/test.sh` (실패해도 OK, 컴파일 통과만 확인)

- [ ] **Step 3: Commit**

```bash
git add EdgeLauncher/Core/Log/AppLog.swift
git commit -m "feat: add AppLog unified logger"
```

---

## Task 2: 미사용 코드 제거

**Files:**
- Delete: `EdgeLauncher/Core/Media/NowPlayingBridge.swift`
- Delete: `EdgeLauncher/Modules/Ambient/` (디렉토리)

- [ ] **Step 1: 삭제**

```bash
rm EdgeLauncher/Core/Media/NowPlayingBridge.swift
rm -rf EdgeLauncher/Modules/Ambient
```

- [ ] **Step 2: 빌드 검증**

`bash scripts/test.sh 2>&1 | grep -E "passed|error:" | tail -5`

기대: 모든 기존 테스트 PASS

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove unused NowPlayingBridge and Ambient module"
```

---

## Task 3: Sparkline 별도 파일 분리

**Files:**
- Create: `EdgeLauncher/Modules/SystemMonitor/Sparkline.swift`
- Modify: `EdgeLauncher/Modules/SystemMonitor/SystemMonitorView.swift`

- [ ] **Step 1: Sparkline.swift 작성**

`EdgeLauncher/Modules/SystemMonitor/Sparkline.swift`:

```swift
import SwiftUI

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let n = max(values.count - 1, 1)

            ZStack {
                ForEach([25.0, 50.0, 75.0], id: \.self) { y in
                    let yPos = h - h * (y / 100.0)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: yPos))
                        p.addLine(to: CGPoint(x: w, y: yPos))
                    }
                    .stroke(.secondary.opacity(0.15), lineWidth: 1)
                }

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(n)
                        let y = h - h * CGFloat(v / 100.0)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.4), color.opacity(0.05)]),
                    startPoint: .top,
                    endPoint: .bottom
                ))

                Path { path in
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(n)
                        let y = h - h * CGFloat(v / 100.0)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, lineWidth: 1.5)
            }
        }
    }
}
```

- [ ] **Step 2: SystemMonitorView에서 Sparkline 정의 제거**

`SystemMonitorView.swift` 의 `struct Sparkline: View {...}` 블록을 삭제 (이미 파일이 분리되었으므로). SystemMonitorView.swift 내 `Sparkline` 참조는 그대로 동작.

- [ ] **Step 3: 빌드 검증**

`bash scripts/test.sh 2>&1 | grep -E "passed|error:" | tail -5`

- [ ] **Step 4: Commit**

```bash
git add EdgeLauncher/Modules/SystemMonitor
git commit -m "refactor: split Sparkline into its own file"
```

---

## Task 4: ProcessColumn 별도 파일 분리

**Files:**
- Create: `EdgeLauncher/Modules/SystemMonitor/ProcessColumn.swift`
- Modify: `EdgeLauncher/Modules/SystemMonitor/SystemMonitorView.swift`

- [ ] **Step 1: ProcessColumn.swift 작성**

`SystemMonitorView.swift` 의 `private struct ProcessColumn` 과 `private struct ProcessRowView` 블록을 `ProcessColumn.swift`로 옮긴다. `private`을 제거하고 `struct ProcessColumn: View`, `struct ProcessRowView: View` 로 변경. callback `onKill`은 그대로 유지.

`EdgeLauncher/Modules/SystemMonitor/ProcessColumn.swift`:

```swift
import SwiftUI

struct ProcessColumn: View {
    let title: String
    let icon: String
    let accent: Color
    let rows: [ProcessRow]
    var valueDescription: String? = nil
    let onKill: (Int, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if let desc = valueDescription {
                    Text(desc)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            if rows.isEmpty {
                VStack {
                    ProgressView().controlSize(.small)
                    Text("샘플링 중...")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                            ProcessRowView(rank: idx + 1, row: row, accent: accent)
                                .contextMenu {
                                    Button("프로세스 정보 복사") {
                                        let text = "\(row.name) (PID \(row.id)) — \(row.value)"
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(text, forType: .string)
                                    }
                                    Divider()
                                    Button("종료 (SIGTERM)") { onKill(row.id, false) }
                                    Button("강제 종료 (SIGKILL)", role: .destructive) { onKill(row.id, true) }
                                }
                            if idx < rows.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProcessRowView: View {
    let rank: Int
    let row: ProcessRow
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 16, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text("PID \(row.id)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(row.value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            GeometryReader { geo in
                Rectangle()
                    .fill(accent.opacity(0.08))
                    .frame(width: geo.size.width * CGFloat(min(row.highlight / 100, 1)))
            }
        )
    }
}
```

- [ ] **Step 2: SystemMonitorView에서 두 구조체 정의 제거**

`SystemMonitorView.swift`의 `private struct ProcessColumn` 과 `private struct ProcessRowView` 정의 전체 삭제.

- [ ] **Step 3: 빌드 검증**

`bash scripts/test.sh 2>&1 | grep -E "passed|error:" | tail -5`

- [ ] **Step 4: Commit**

```bash
git add EdgeLauncher/Modules/SystemMonitor
git commit -m "refactor: split ProcessColumn/ProcessRowView into own file"
```

---

## Task 5: WidgetDashboardView 분리 (4개 패널)

**Files:**
- Create: `EdgeLauncher/Modules/WidgetDashboard/ClockHero.swift`
- Create: `EdgeLauncher/Modules/WidgetDashboard/WeatherPanel.swift`
- Create: `EdgeLauncher/Modules/WidgetDashboard/OutlookPanel.swift`
- Create: `EdgeLauncher/Modules/WidgetDashboard/RemindersPanel.swift`
- Modify: `EdgeLauncher/Modules/WidgetDashboard/WidgetDashboardView.swift` (컨테이너만)

- [ ] **Step 1: ClockHero.swift 작성**

기존 `WidgetDashboardView.swift` 의 `private var clockHero: some View` 와 `private func statPill(...)` 블록을 추출.

```swift
import SwiftUI

struct ClockHero: View {
    let now: Date

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.18),
                    Color(red: 0.14, green: 0.18, blue: 0.28),
                    Color(red: 0.10, green: 0.12, blue: 0.20),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geo in
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentColor.opacity(0.35), Color.purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 220, height: 220)
                        .blur(radius: 50)
                        .offset(x: CGFloat(i) * 320 - 100, y: CGFloat(i % 2 == 0 ? -40 : 40))
                }
            }

            HStack(spacing: 40) {
                Text(timeText)
                    .font(.system(size: 132, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .white.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color.accentColor.opacity(0.6), radius: 22)

                VStack(alignment: .leading, spacing: 10) {
                    Text(dateText)
                        .font(.system(size: 32, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                    Text(dayText)
                        .font(.system(size: 24, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    HStack(spacing: 12) {
                        statPill(label: "주", value: weekProgress)
                        statPill(label: "연", value: "\(dayOfYear)/365")
                    }
                    .padding(.top, 6)
                }

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .frame(height: 220)
    }

    private func statPill(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.55))
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.12), in: Capsule())
    }

    private var timeText: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: now)
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
```

- [ ] **Step 2: WeatherPanel.swift 작성**

기존 `weatherPanel`, `weatherBody`, `weatherPermission`, `weatherStat`, `relativeUpdate` 를 옮긴다.

```swift
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
```

- [ ] **Step 3: OutlookPanel.swift 작성**

기존 `outlookPanel`, `eventRow`, `timeRange` 와 보조 (`permissionBanner`, `emptyState`)를 옮긴다.

```swift
import EventKit
import SwiftUI

struct OutlookPanel: View {
    @ObservedObject var eventVM: EventStoreVM

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !eventVM.hasEventAccess {
                permissionBanner(message: "캘린더 권한이 필요합니다")
            } else if eventVM.events.isEmpty {
                emptyState("오늘 일정 없음", system: "checkmark.circle")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(eventVM.events, id: \.eventIdentifier) { eventRow($0) }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            Label("오늘 일정", systemImage: "calendar").font(.system(size: 18, weight: .semibold))
            Spacer()
            if eventVM.hasEventAccess {
                Text("\(eventVM.events.count)건").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            }
            Button(action: { eventVM.reloadEvents() }) {
                Image(systemName: "arrow.clockwise").font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func eventRow(_ event: EKEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(cgColor: event.calendar?.cgColor ?? CGColor(red: 0.4, green: 0.6, blue: 1, alpha: 1)))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "(제목 없음)").font(.system(size: 16, weight: .semibold)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(timeRange(event)).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                    if let loc = event.location, !loc.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(loc).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                if let cal = event.calendar {
                    Text(cal.title).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func permissionBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "lock.fill").font(.system(size: 14, weight: .semibold))
            Text("시스템 설정 > 개인정보 보호 및 보안에서 EdgeLauncher 허용.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Button("권한 다시 요청") { Task { await eventVM.requestAccess() } }.controlSize(.small)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func emptyState(_ title: String, system: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: system).font(.system(size: 32)).foregroundStyle(.green)
            Text(title).font(.system(size: 14)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 24)
    }

    private func timeRange(_ event: EKEvent) -> String {
        if event.isAllDay { return "종일" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "\(f.string(from: event.startDate)) – \(f.string(from: event.endDate))"
    }
}
```

- [ ] **Step 4: RemindersPanel.swift 작성**

```swift
import EventKit
import SwiftUI

struct RemindersPanel: View {
    @ObservedObject var eventVM: EventStoreVM

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !eventVM.hasReminderAccess {
                permissionBanner
            } else if eventVM.reminders.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(eventVM.reminders, id: \.calendarItemIdentifier) { reminderRow($0) }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            Label("미리알림", systemImage: "checklist").font(.system(size: 18, weight: .semibold))
            Spacer()
            if eventVM.hasReminderAccess {
                Text("\(eventVM.reminders.count)건").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            }
            Button(action: { eventVM.reloadReminders() }) {
                Image(systemName: "arrow.clockwise").font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func reminderRow(_ reminder: EKReminder) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: { eventVM.toggleComplete(reminder) }) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(reminder.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title ?? "(제목 없음)")
                    .font(.system(size: 15, weight: .medium))
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                    .lineLimit(1)
                if let due = reminder.dueDateComponents?.date {
                    Text(dueLabel(due))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(isOverdue(due, completed: reminder.isCompleted) ? .red : .secondary)
                }
                if let cal = reminder.calendar {
                    Text(cal.title).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("미리알림 권한이 필요합니다", systemImage: "lock.fill").font(.system(size: 14, weight: .semibold))
            Text("시스템 설정 > 개인정보 보호 및 보안에서 EdgeLauncher 허용.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Button("권한 다시 요청") { Task { await eventVM.requestAccess() } }.controlSize(.small)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 32)).foregroundStyle(.green)
            Text("미리알림 없음").font(.system(size: 14)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 24)
    }

    private func dueLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR")
        let cal = Calendar.current
        if cal.isDateInToday(date) { f.dateFormat = "HH:mm '오늘'" }
        else if cal.isDateInTomorrow(date) { f.dateFormat = "HH:mm '내일'" }
        else { f.dateFormat = "M월 d일 HH:mm" }
        return f.string(from: date)
    }

    private func isOverdue(_ date: Date, completed: Bool) -> Bool {
        !completed && date < Date()
    }
}
```

- [ ] **Step 5: WidgetDashboardView 컨테이너만 남기기**

`WidgetDashboardView.swift` 전체 교체:

```swift
import Combine
import SwiftUI

struct WidgetDashboardView: View {
    @State private var now = Date()
    @StateObject private var eventVM = EventStoreVM()
    @StateObject private var weather = WeatherService()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ClockHero(now: now)
            Divider()
            HStack(spacing: 0) {
                WeatherPanel(weather: weather).frame(width: 320)
                Divider()
                OutlookPanel(eventVM: eventVM)
                Divider()
                RemindersPanel(eventVM: eventVM)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(timer) { now = $0 }
        .task {
            await eventVM.requestAccess()
            weather.start()
        }
    }
}
```

- [ ] **Step 6: 빌드 검증**

`bash scripts/test.sh 2>&1 | grep -E "passed|error:" | tail -10`

- [ ] **Step 7: Commit**

```bash
git add EdgeLauncher/Modules/WidgetDashboard
git commit -m "refactor: split WidgetDashboardView into 4 panel files"
```

---

## Task 6: EdgeModule lifecycle 훅 + 테스트

**Files:**
- Modify: `EdgeLauncher/Core/Module/EdgeModule.swift`
- Modify: `EdgeLauncher/Core/Module/ModuleRegistry.swift`
- Create: `EdgeLauncherTests/EdgeModuleLifecycleTests.swift`

- [ ] **Step 1: 테스트 작성**

`EdgeLauncherTests/EdgeModuleLifecycleTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import EdgeLauncher

final class EdgeModuleLifecycleTests: XCTestCase {
    func test_defaults_are_noop() {
        var mod = TrackingModule()
        mod.didBecomeActive()
        mod.didResignActive()
        XCTAssertEqual(mod.becameActiveCount, 1)
        XCTAssertEqual(mod.resignedCount, 1)
    }

    func test_any_module_forwards_lifecycle() {
        let mod = TrackingModule()
        let any = AnyEdgeModule(mod)
        any.didBecomeActive()
        any.didResignActive()
        XCTAssertEqual(mod.shared.becameActiveCount, 1)
        XCTAssertEqual(mod.shared.resignedCount, 1)
    }
}

private struct TrackingModule: EdgeModule {
    let id = "tracker"
    let title = "Tracker"
    let iconName = "circle"
    let supportsFullscreen = false
    var view: some View { Text("tracker") }

    final class Shared {
        var becameActiveCount = 0
        var resignedCount = 0
    }
    let shared = Shared()
    var becameActiveCount: Int { shared.becameActiveCount }
    var resignedCount: Int { shared.resignedCount }

    func didBecomeActive() { shared.becameActiveCount += 1 }
    func didResignActive() { shared.resignedCount += 1 }
}
```

- [ ] **Step 2: EdgeModule 프로토콜에 lifecycle 추가**

`EdgeLauncher/Core/Module/EdgeModule.swift` 전체 교체:

```swift
import SwiftUI

protocol EdgeModule {
    associatedtype Body: View
    var id: String { get }
    var title: String { get }
    var iconName: String { get }
    var supportsFullscreen: Bool { get }
    @ViewBuilder var view: Body { get }

    func didBecomeActive()
    func didResignActive()
}

extension EdgeModule {
    func didBecomeActive() {}
    func didResignActive() {}
}
```

- [ ] **Step 3: AnyEdgeModule에 forwarding 추가**

`ModuleRegistry.swift` 의 AnyEdgeModule 정의 수정:

```swift
struct AnyEdgeModule: Identifiable {
    let id: String
    let title: String
    let iconName: String
    let supportsFullscreen: Bool
    let viewBuilder: () -> AnyView
    let becameActive: () -> Void
    let resigned: () -> Void

    init<M: EdgeModule>(_ module: M) {
        self.id = module.id
        self.title = module.title
        self.iconName = module.iconName
        self.supportsFullscreen = module.supportsFullscreen
        self.viewBuilder = { AnyView(module.view) }
        self.becameActive = { module.didBecomeActive() }
        self.resigned = { module.didResignActive() }
    }

    func didBecomeActive() { becameActive() }
    func didResignActive() { resigned() }
}
```

- [ ] **Step 4: 테스트 통과 확인**

`bash scripts/test.sh 2>&1 | grep -E "Lifecycle|passed|FAILED" | tail -10`

- [ ] **Step 5: Commit**

```bash
git add EdgeLauncher/Core/Module EdgeLauncherTests/EdgeModuleLifecycleTests.swift
git commit -m "feat: add EdgeModule lifecycle hooks (didBecomeActive/Resign)"
```

---

## Task 7: TabRouter lifecycle 콜백

**Files:**
- Modify: `EdgeLauncher/UI/TabRouter.swift`

- [ ] **Step 1: TabRouter 수정**

```swift
import Combine
import Foundation

final class TabRouter: ObservableObject {
    @Published private(set) var activeID: String? {
        didSet { defaults.set(activeID, forKey: Self.key) }
    }

    private let defaults: UserDefaults
    private static let key = "app.activeTab"
    private(set) weak var registry: ModuleRegistry?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.activeID = defaults.string(forKey: Self.key)
    }

    func attach(registry: ModuleRegistry) {
        self.registry = registry
    }

    func activate(_ id: String) {
        guard id != activeID else { return }
        let previousID = activeID
        activeID = id
        if let previousID, let prev = registry?.module(id: previousID) {
            prev.didResignActive()
        }
        if let next = registry?.module(id: id) {
            next.didBecomeActive()
        }
    }
}
```

- [ ] **Step 2: AppEnvironment.init에 attach 추가**

`AppEnvironment.swift` 의 `init()` 안의 `self.router = router` 다음에 `router.attach(registry: registry)` 추가.

- [ ] **Step 3: 기존 TabRouter 테스트 호환 확인**

기존 `TabRouterTests` 가 `activeID` 직접 할당 또는 `activate()` 호출을 어떻게 하는지 확인. `activate(_:)`가 same id면 무동작인 점 때문에 테스트가 깨질 수 있다.

`EdgeLauncherTests/TabRouterTests.swift` 의 `test_activate_sets_id` 확인 — `activate("youtube")` 호출이므로 이전 값이 nil 일 때는 무조건 변경. OK.

- [ ] **Step 4: 빌드 + 테스트**

`bash scripts/test.sh 2>&1 | grep -E "passed|FAILED" | tail -15`

- [ ] **Step 5: Commit**

```bash
git add EdgeLauncher/UI/TabRouter.swift EdgeLauncher/App/AppEnvironment.swift
git commit -m "feat: TabRouter calls didBecomeActive/Resign on registry modules"
```

---

## Task 8: SystemMonitor/Widget 모듈 lifecycle 적용

**Files:**
- Modify: `EdgeLauncher/Modules/SystemMonitor/SystemMonitorModule.swift`
- Modify: `EdgeLauncher/Modules/WidgetDashboard/WidgetDashboardModule.swift`
- Modify: `EdgeLauncher/Modules/SystemMonitor/SystemStats.swift`
- Modify: `EdgeLauncher/Modules/SystemMonitor/ProcessStats.swift`
- Modify: `EdgeLauncher/Modules/WidgetDashboard/WeatherService.swift`

- [ ] **Step 1: SystemMonitorModule lifecycle**

```swift
import SwiftUI

final class SystemMonitorModule: EdgeModule {
    let id = "system-monitor"
    let title = "Monitor"
    let iconName = "cpu"
    let supportsFullscreen = false

    private static let stats = SystemStats()
    private static let procs = ProcessStats()

    var view: some View { SystemMonitorView(stats: Self.stats, procs: Self.procs) }

    func didBecomeActive() { Self.stats.start(); Self.procs.start() }
    func didResignActive() { Self.stats.stop(); Self.procs.stop() }
}
```

- [ ] **Step 2: SystemMonitorView 의존성 수정**

`SystemMonitorView.swift`의 `@StateObject private var stats = SystemStats()` 와 `procs` 를 `@ObservedObject` 로 변경하고, init에서 받도록.

```swift
struct SystemMonitorView: View {
    @ObservedObject var stats: SystemStats
    @ObservedObject var procs: ProcessStats
    ...
}
```

- [ ] **Step 3: SystemStats / ProcessStats stop/start API 확인**

`SystemStats.start()`, `SystemStats.stop()` 이미 존재. `ProcessStats.start()/stop()` 이미 존재. init에서 자동 start 하는 부분을 제거하여 외부 통제로 변경:

`SystemStats.init`:
```swift
init() {
    _ = sampleCPU()  // baseline
    // Timer는 외부 start() 호출로 시작
}
```

`ProcessStats.init`:
```swift
init() {
    refresh()  // 첫 sample만, Timer 시작은 외부
}
```

- [ ] **Step 4: WidgetDashboardModule lifecycle**

```swift
import SwiftUI

final class WidgetDashboardModule: EdgeModule {
    let id = "widgets"
    let title = "Widgets"
    let iconName = "rectangle.grid.2x2"
    let supportsFullscreen = false

    private static let eventVM = EventStoreVM()
    private static let weather = WeatherService()

    var view: some View { WidgetDashboardView(eventVM: Self.eventVM, weather: Self.weather) }

    func didBecomeActive() {
        Task { await Self.eventVM.requestAccess() }
        Self.weather.start()
    }

    func didResignActive() {
        Self.weather.stop()
    }
}
```

- [ ] **Step 5: WidgetDashboardView 의존성 수정**

```swift
struct WidgetDashboardView: View {
    @ObservedObject var eventVM: EventStoreVM
    @ObservedObject var weather: WeatherService
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ClockHero(now: now)
            Divider()
            HStack(spacing: 0) {
                WeatherPanel(weather: weather).frame(width: 320)
                Divider()
                OutlookPanel(eventVM: eventVM)
                Divider()
                RemindersPanel(eventVM: eventVM)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(timer) { now = $0 }
    }
}
```

- [ ] **Step 6: 빌드 + 테스트**

`bash scripts/test.sh 2>&1 | grep -E "passed|FAILED|error:" | tail -10`

- [ ] **Step 7: Commit**

```bash
git add EdgeLauncher/Modules
git commit -m "feat: pause Monitor/Widget timers when modules become inactive"
```

---

## Task 9: WKWebView lazy load

**Files:**
- Modify: `EdgeLauncher/UI/RootView.swift`

- [ ] **Step 1: RootView 수정**

기존 `content` 의 ZStack 로직을 변경. 활성화된 적 있는 모듈만 ZStack에 등록.

```swift
struct RootView: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter
    @EnvironmentObject var displayService: XeneonDisplayService
    @Environment(\.openSettings) private var openSettings
    @State private var activated: Set<String> = []

    // ... header 등 기존 유지

    @ViewBuilder
    private var content: some View {
        if registry.modules.isEmpty {
            placeholder
        } else {
            ZStack {
                ForEach(registry.modules) { module in
                    if activated.contains(module.id) {
                        module.viewBuilder()
                            .opacity(router.activeID == module.id ? 1 : 0)
                            .allowsHitTesting(router.activeID == module.id)
                            .accessibilityHidden(router.activeID != module.id)
                    }
                }
            }
            .onAppear {
                if let id = router.activeID { activated.insert(id) }
            }
            .onChange(of: router.activeID) { _, newID in
                if let id = newID { activated.insert(id) }
            }
        }
    }
}
```

- [ ] **Step 2: 빌드 검증**

`bash scripts/test.sh 2>&1 | grep -E "passed|error:" | tail -5`

- [ ] **Step 3: Commit**

```bash
git add EdgeLauncher/UI/RootView.swift
git commit -m "feat: lazy load module views only after first activation"
```

---

## Task 10: 키보드 단축키

**Files:**
- Modify: `EdgeLauncher/EdgeLauncherApp.swift`

- [ ] **Step 1: 메뉴 커맨드 추가**

`EdgeLauncherApp.swift` 의 `body: some Scene` 에 `.commands { ... }` 블록 추가:

```swift
WindowGroup("Edge Launcher") {
    RootView()
        .environmentObject(env.registry)
        .environmentObject(env.router)
        .environmentObject(env.displayService)
        .frame(minWidth: 1280, idealWidth: 2560, minHeight: 480, idealHeight: 720)
        .onAppear { handleAppear() }
}
.windowResizability(.automatic)
.commands {
    CommandGroup(replacing: .newItem) {}
    CommandMenu("탭") {
        ForEach(Array(env.registry.modules.enumerated()), id: \.element.id) { idx, module in
            if idx < 9 {
                Button(module.title) {
                    env.router.activate(module.id)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")), modifiers: .command)
            }
        }
        Divider()
        Button("새로고침") { reloadActive() }
            .keyboardShortcut("r", modifiers: .command)
    }
}
```

- [ ] **Step 2: reloadActive 메서드 추가**

`EdgeLauncherApp` 안에:

```swift
private func reloadActive() {
    NotificationCenter.default.post(name: .moduleReloadRequested, object: nil)
}
```

- [ ] **Step 3: Notification 정의**

`EdgeLauncher/Core/Window/EdgeWindowController.swift` 마지막에:

```swift
extension Notification.Name {
    static let moduleReloadRequested = Notification.Name("module.reload.requested")
}
```

- [ ] **Step 4: WebView 모듈에서 reload 옵저버**

`YouTubeWebView.swift`, `YouTubeMusicWebView.swift`, `MessengerView.swift` 의 `makeNSView` 후에 NotificationCenter 옵저버 추가는 까다로움. 대안: WKWebView 인스턴스에 reload 명령을 보낼 wrapper view.

간단한 방법: `RootView` 또는 `EdgeLauncherApp.handleAppear`에서 옵저버 등록하고, 활성 모듈이 webview 면 reload. 추적 단순화 위해 lifecycle의 새 메서드 `reload()` 를 EdgeModule에 추가 — 본 plan에는 미포함 (Phase 3 후보).

대신 `Cmd+R` 은 `WKWebView.reload()` 가 자동 처리되도록 macOS 표준 메뉴 connect:
```swift
Button("새로고침") {
    NSApp.sendAction(#selector(WKWebView.reload(_:)), to: nil, from: nil)
}
.keyboardShortcut("r", modifiers: .command)
```

이게 first responder인 WKWebView 에 전달됨. WebView 활성일 때만 동작.

- [ ] **Step 5: 빌드 + 실행 검증**

```bash
make deploy
```

Cmd+1, Cmd+2 등 동작 확인.

- [ ] **Step 6: Commit**

```bash
git add EdgeLauncher/EdgeLauncherApp.swift EdgeLauncher/Core/Window/EdgeWindowController.swift
git commit -m "feat: Cmd+1..N tab shortcuts and Cmd+R reload"
```

---

## Task 11: ModuleRegistry 순서 변경 + 표시 토글

**Files:**
- Modify: `EdgeLauncher/Core/Module/ModuleRegistry.swift`
- Create: `EdgeLauncherTests/ModuleRegistryReorderTests.swift`

- [ ] **Step 1: 테스트 작성**

```swift
import XCTest
@testable import EdgeLauncher

final class ModuleRegistryReorderTests: XCTestCase {
    func test_reorder_moves_module() {
        let reg = ModuleRegistry()
        reg.register(AnyEdgeModule(StubModule(id: "a", title: "A", iconName: "circle")))
        reg.register(AnyEdgeModule(StubModule(id: "b", title: "B", iconName: "circle")))
        reg.register(AnyEdgeModule(StubModule(id: "c", title: "C", iconName: "circle")))
        reg.reorder(from: 0, to: 2)
        XCTAssertEqual(reg.modules.map(\.id), ["b", "c", "a"])
    }

    func test_hide_filters_visible_modules() {
        let reg = ModuleRegistry()
        reg.register(AnyEdgeModule(StubModule(id: "a", title: "A", iconName: "circle")))
        reg.register(AnyEdgeModule(StubModule(id: "b", title: "B", iconName: "circle")))
        reg.setVisible("b", visible: false)
        XCTAssertEqual(reg.visibleModules.map(\.id), ["a"])
    }
}
```

- [ ] **Step 2: ModuleRegistry 확장**

```swift
final class ModuleRegistry: ObservableObject {
    @Published private(set) var modules: [AnyEdgeModule] = []
    @Published private(set) var hiddenIDs: Set<String> = []

    private let orderKey = "app.moduleOrder"
    private let hiddenKey = "app.moduleHidden"

    init() {
        let stored = (UserDefaults.standard.array(forKey: hiddenKey) as? [String]) ?? []
        hiddenIDs = Set(stored)
    }

    func register(_ module: AnyEdgeModule) {
        if let idx = modules.firstIndex(where: { $0.id == module.id }) {
            modules[idx] = module
        } else {
            modules.append(module)
        }
        applyStoredOrder()
    }

    func module(id: String) -> AnyEdgeModule? {
        modules.first { $0.id == id }
    }

    var visibleModules: [AnyEdgeModule] {
        modules.filter { !hiddenIDs.contains($0.id) }
    }

    func reorder(from: Int, to: Int) {
        guard from != to, from >= 0, from < modules.count, to >= 0, to <= modules.count else { return }
        let item = modules.remove(at: from)
        modules.insert(item, at: to >= modules.count ? modules.count : to)
        persistOrder()
    }

    func setVisible(_ id: String, visible: Bool) {
        if visible { hiddenIDs.remove(id) } else { hiddenIDs.insert(id) }
        UserDefaults.standard.set(Array(hiddenIDs), forKey: hiddenKey)
    }

    private func persistOrder() {
        UserDefaults.standard.set(modules.map(\.id), forKey: orderKey)
    }

    private func applyStoredOrder() {
        guard let order = UserDefaults.standard.array(forKey: orderKey) as? [String], !order.isEmpty else { return }
        let mapping = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        modules.sort { (a, b) in
            (mapping[a.id] ?? Int.max) < (mapping[b.id] ?? Int.max)
        }
    }
}
```

- [ ] **Step 3: 테스트 통과**

`bash scripts/test.sh 2>&1 | grep -E "Reorder|passed|FAILED" | tail -10`

- [ ] **Step 4: Sidebar에 visibleModules 적용**

`Sidebar.swift` 의 `ForEach(registry.modules)` 를 `ForEach(registry.visibleModules)` 로 변경.

- [ ] **Step 5: Commit**

```bash
git add EdgeLauncher/Core/Module EdgeLauncher/UI/Sidebar.swift EdgeLauncherTests/ModuleRegistryReorderTests.swift
git commit -m "feat: ModuleRegistry reorder and visibility toggle"
```

---

## Task 12: 모듈 표시 토글 UI

**Files:**
- Create: `EdgeLauncher/Settings/ModuleVisibilityView.swift`
- Modify: `EdgeLauncher/Settings/SettingsView.swift`

- [ ] **Step 1: ModuleVisibilityView 작성**

```swift
import SwiftUI

struct ModuleVisibilityView: View {
    @EnvironmentObject var registry: ModuleRegistry

    var body: some View {
        Form {
            Section("표시할 탭") {
                ForEach(registry.modules) { module in
                    let isVisible = !registry.hiddenIDs.contains(module.id)
                    Toggle(isOn: Binding(
                        get: { isVisible },
                        set: { registry.setVisible(module.id, visible: $0) }
                    )) {
                        Label(module.title, systemImage: module.iconName)
                    }
                }
            }
        }
        .padding(20)
    }
}
```

- [ ] **Step 2: SettingsView에서 두 번째 탭 교체**

```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var env: AppEnvironment
    @AppStorage("app.autoMoveOnLaunch") private var autoMoveOnLaunch = true
    @AppStorage("app.startInFullScreen") private var startInFullScreen = true

    var body: some View {
        TabView {
            Form {
                Toggle("앱 실행 시 Xeneon Edge로 자동 이동", isOn: $autoMoveOnLaunch)
                Toggle("Edge 이동 시 자동 풀스크린", isOn: $startInFullScreen)
            }
            .padding(24)
            .tabItem { Label("일반", systemImage: "gearshape") }

            ModuleVisibilityView()
                .environmentObject(env.registry)
                .tabItem { Label("탭", systemImage: "rectangle.split.3x1") }
        }
        .frame(width: 520, height: 320)
    }
}
```

- [ ] **Step 3: 빌드**

`make deploy`. 설정 열어 토글 동작 확인.

- [ ] **Step 4: Commit**

```bash
git add EdgeLauncher/Settings
git commit -m "feat: ModuleVisibilityView in Settings to toggle tabs"
```

---

## Task 13: 사이드바 drag&drop 순서 변경

**Files:**
- Modify: `EdgeLauncher/UI/Sidebar.swift`

- [ ] **Step 1: ForEach에 onMove 적용**

SwiftUI ScrollView 안의 ForEach는 `.onMove` 가 List 외에서는 미동작. 임시로 `.onDrag` + `.onDrop` 으로 처리.

```swift
ForEach(registry.visibleModules) { module in
    TouchableTabButton(...) { router.activate(module.id) }
        .onDrag { NSItemProvider(object: module.id as NSString) }
        .onDrop(of: [.plainText], delegate: ModuleDropDelegate(target: module.id, registry: registry))
}
```

`ModuleDropDelegate`:

```swift
struct ModuleDropDelegate: DropDelegate {
    let target: String
    let registry: ModuleRegistry

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.plainText]).first else { return false }
        item.loadObject(ofClass: NSString.self) { source, _ in
            guard let sourceID = source as? String else { return }
            DispatchQueue.main.async {
                if let from = registry.modules.firstIndex(where: { $0.id == sourceID }),
                   let to = registry.modules.firstIndex(where: { $0.id == target }) {
                    registry.reorder(from: from, to: to)
                }
            }
        }
        return true
    }
}
```

`UTType.plainText` import: `import UniformTypeIdentifiers`.

- [ ] **Step 2: 빌드 + 실행 검증**

`make deploy`. 사이드바 모듈을 드래그해서 순서 변경 가능한지 확인.

- [ ] **Step 3: Commit**

```bash
git add EdgeLauncher/UI/Sidebar.swift
git commit -m "feat: drag-and-drop sidebar module reorder"
```

---

## Task 14: TouchScrollContainer

**Files:**
- Create: `EdgeLauncher/Core/Touch/TouchScrollContainer.swift`
- Create: `EdgeLauncher/Core/Touch/TouchPanGestureInstaller.swift`
- Modify: `EdgeLauncher/UI/Sidebar.swift`

- [ ] **Step 1: TouchPanGestureInstaller**

```swift
import AppKit

enum TouchPanGestureInstaller {
    static func install(on scrollView: NSScrollView) {
        let overlay = TouchPanOverlayView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.targetScrollView = scrollView
        scrollView.addSubview(overlay, positioned: .above, relativeTo: nil)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: scrollView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ])
    }
}

final class TouchPanOverlayView: NSView {
    weak var targetScrollView: NSScrollView?
    private var startTouchY: CGFloat = 0
    private var startScrollY: CGFloat = 0
    private var isTracking = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        allowedTouchTypes = [.direct]
    }
    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // 자식 뷰가 이벤트 받도록 통과시키되 touch는 직접 처리
        return nil
    }

    override func touchesBegan(with event: NSEvent) {
        guard let touch = event.touches(matching: .began, in: self).first else { return }
        let loc = touch.location(in: self)
        startTouchY = loc.y
        startScrollY = targetScrollView?.contentView.bounds.origin.y ?? 0
        isTracking = true
    }

    override func touchesMoved(with event: NSEvent) {
        guard isTracking, let touch = event.touches(matching: .moved, in: self).first else { return }
        let loc = touch.location(in: self)
        let delta = loc.y - startTouchY
        if let scrollView = targetScrollView {
            var origin = scrollView.contentView.bounds.origin
            origin.y = max(0, startScrollY - delta)
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    override func touchesEnded(with event: NSEvent) { isTracking = false }
    override func touchesCancelled(with event: NSEvent) { isTracking = false }
}
```

- [ ] **Step 2: TouchScrollContainer**

```swift
import SwiftUI

struct TouchScrollContainer<Content: View>: NSViewRepresentable {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let hosting = NSHostingView(rootView: content)
        scrollView.documentView = hosting
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        TouchPanGestureInstaller.install(on: scrollView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let host = nsView.documentView as? NSHostingView<Content> {
            host.rootView = content
        }
    }
}
```

- [ ] **Step 3: Sidebar에 적용**

기존 `ScrollView(showsIndicators: false) { ... }` 부분을:

```swift
TouchScrollContainer {
    VStack(spacing: 6) {
        ForEach(registry.visibleModules) { module in
            ...
        }
    }
    .padding(.vertical, 10)
}
```

- [ ] **Step 4: 빌드 + 실기기 검증**

`make deploy`. Xeneon Edge에서 사이드바 손가락 위/아래 드래그로 스크롤 시도.

- [ ] **Step 5: Commit**

```bash
git add EdgeLauncher/Core/Touch EdgeLauncher/UI/Sidebar.swift
git commit -m "feat: TouchScrollContainer enables finger panning on sidebar"
```

---

## Task 15: 풀스크린 chrome 자동 숨김

**Files:**
- Create: `EdgeLauncher/Core/Window/ChromeVisibilityController.swift`
- Modify: `EdgeLauncher/UI/RootView.swift`

- [ ] **Step 1: ChromeVisibilityController**

```swift
import AppKit
import Combine

@MainActor
final class ChromeVisibilityController: ObservableObject {
    @Published var chromeVisible: Bool = true
    private var idleTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scheduleHide() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didExitFullScreenNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.idleTimer?.invalidate()
                self?.chromeVisible = true
            }
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func notifyMouseMoved() {
        chromeVisible = true
        scheduleHide()
    }

    private func scheduleHide() {
        idleTimer?.invalidate()
        guard let window = NSApp.mainWindow, window.styleMask.contains(.fullScreen) else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.chromeVisible = false
            }
        }
    }
}
```

- [ ] **Step 2: RootView에 적용**

```swift
struct RootView: View {
    ...
    @StateObject private var chrome = ChromeVisibilityController()

    var body: some View {
        VStack(spacing: 0) {
            if chrome.chromeVisible {
                headerBar
                    .transition(.move(edge: .top).combined(with: .opacity))
                Divider()
            }
            HStack(spacing: 0) {
                if chrome.chromeVisible {
                    Sidebar()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    Divider()
                }
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 1280, minHeight: 480)
        .animation(.easeInOut(duration: 0.25), value: chrome.chromeVisible)
        .onContinuousHover { phase in
            if case .active = phase { chrome.notifyMouseMoved() }
        }
    }
}
```

- [ ] **Step 3: 빌드 + 검증**

`make deploy`. 풀스크린 진입 후 3초 idle → chrome 숨김 → 마우스 이동 시 다시 표시.

- [ ] **Step 4: Commit**

```bash
git add EdgeLauncher/Core/Window EdgeLauncher/UI/RootView.swift
git commit -m "feat: auto-hide chrome (header/sidebar) after 3s idle in fullscreen"
```

---

## Task 16: ErrorBus + ErrorBanner

**Files:**
- Create: `EdgeLauncher/Core/Error/ErrorBus.swift`
- Create: `EdgeLauncher/Core/Error/ErrorBanner.swift`
- Modify: `EdgeLauncher/UI/RootView.swift`
- Modify: `EdgeLauncher/Modules/WidgetDashboard/WeatherService.swift`
- Modify: `EdgeLauncher/Modules/WidgetDashboard/EventStoreVM.swift`
- Modify: `EdgeLauncher/Modules/Launcher/LauncherStore.swift`

- [ ] **Step 1: ErrorBus**

```swift
import Combine
import Foundation

@MainActor
final class ErrorBus: ObservableObject {
    static let shared = ErrorBus()
    @Published var current: AppError?

    struct AppError: Identifiable, Equatable {
        let id = UUID()
        let category: String
        let message: String
    }

    func publish(_ category: String, _ message: String) {
        current = AppError(category: category, message: message)
    }

    func dismiss() { current = nil }
}
```

- [ ] **Step 2: ErrorBanner**

```swift
import SwiftUI

struct ErrorBanner: View {
    @ObservedObject var bus: ErrorBus

    var body: some View {
        if let err = bus.current {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(err.category).font(.system(size: 11, weight: .semibold))
                    Text(err.message).font(.system(size: 11)).lineLimit(2)
                }
                Spacer()
                Button(action: { bus.dismiss() }) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.18))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
```

- [ ] **Step 3: RootView 상단에 부착**

`headerBar` 위에 `ErrorBanner(bus: ErrorBus.shared)` 추가.

- [ ] **Step 4: WeatherService → ErrorBus**

`WeatherService.swift` 의 `errorMessage = ...` 가 있는 catch들에 다음 한 줄 추가:

```swift
AppLog.weather.error("\(error.localizedDescription)")
ErrorBus.shared.publish("날씨", error.localizedDescription)
```

- [ ] **Step 5: EventStoreVM → ErrorBus**

`EventStoreVM.swift` 의 catch에 동일 패턴.

- [ ] **Step 6: LauncherStore → ErrorBus**

`LauncherStore.launch(_:)` 의 `FileManager.fileExists == false` 분기에서:

```swift
ErrorBus.shared.publish("런처", "앱을 찾을 수 없습니다: \(entry.bundleURL)")
```

- [ ] **Step 7: 빌드 + 검증**

`make deploy`. 권한 거부 등의 상황에서 노란 배너 표시 확인.

- [ ] **Step 8: Commit**

```bash
git add EdgeLauncher/Core/Error EdgeLauncher/UI/RootView.swift EdgeLauncher/Modules
git commit -m "feat: ErrorBus + ErrorBanner unified error feedback"
```

---

## Task 17: Phase 2 모듈 테스트 + Discord parser 테스트

**Files:**
- Create: `EdgeLauncherTests/Phase2ModuleMetadataTests.swift`
- Create: `EdgeLauncherTests/DiscordParseUnreadTests.swift`
- Create: `EdgeLauncherTests/LauncherStoreTests.swift`
- Modify: `EdgeLauncher/Modules/Messenger/MessengerView.swift` (parseUnread를 internal로)

- [ ] **Step 1: Discord parser internal로 변경**

`MessengerView.swift` 의 `DiscordWebView.Coordinator` 내부 `static func parseUnread` 를 fileprivate에서 internal로 변경하고 동일한 위치 유지.

- [ ] **Step 2: DiscordParseUnreadTests 작성**

```swift
import XCTest
@testable import EdgeLauncher

final class DiscordParseUnreadTests: XCTestCase {
    func test_no_count_when_title_lacks_paren() {
        XCTAssertEqual(DiscordWebView.Coordinator.parseUnread(title: "Discord"), 0)
    }

    func test_extracts_count_from_paren_prefix() {
        XCTAssertEqual(DiscordWebView.Coordinator.parseUnread(title: "(5) Discord | #general"), 5)
    }

    func test_two_digit_count() {
        XCTAssertEqual(DiscordWebView.Coordinator.parseUnread(title: "(42) Discord"), 42)
    }

    func test_non_numeric_inside_paren_returns_zero() {
        XCTAssertEqual(DiscordWebView.Coordinator.parseUnread(title: "(!) Discord"), 0)
    }
}
```

- [ ] **Step 3: Phase2ModuleMetadataTests**

```swift
import XCTest
import SwiftUI
@testable import EdgeLauncher

final class Phase2ModuleMetadataTests: XCTestCase {
    func test_system_monitor_module() {
        let m = SystemMonitorModule()
        XCTAssertEqual(m.id, "system-monitor")
        XCTAssertEqual(m.title, "Monitor")
        XCTAssertEqual(m.iconName, "cpu")
        XCTAssertFalse(m.supportsFullscreen)
    }

    func test_widget_dashboard_module() {
        let m = WidgetDashboardModule()
        XCTAssertEqual(m.id, "widgets")
        XCTAssertEqual(m.title, "Widgets")
        XCTAssertEqual(m.iconName, "rectangle.grid.2x2")
        XCTAssertFalse(m.supportsFullscreen)
    }

    func test_messenger_module() {
        let m = MessengerModule()
        XCTAssertEqual(m.id, "messenger")
        XCTAssertEqual(m.title, "Discord")
        XCTAssertEqual(m.iconName, "bubble.left.and.bubble.right.fill")
        XCTAssertTrue(m.supportsFullscreen)
    }

    func test_launcher_module() {
        let m = LauncherModule()
        XCTAssertEqual(m.id, "launcher")
        XCTAssertEqual(m.title, "Launcher")
        XCTAssertEqual(m.iconName, "square.grid.3x3.fill")
        XCTAssertFalse(m.supportsFullscreen)
    }
}
```

- [ ] **Step 4: LauncherStoreTests**

```swift
import XCTest
@testable import EdgeLauncher

@MainActor
final class LauncherStoreTests: XCTestCase {
    func test_add_appends_new_entry() {
        let store = LauncherStore()
        let initialCount = store.entries.count
        store.add(url: URL(fileURLWithPath: "/Applications/Some_NewApp.app"))
        XCTAssertEqual(store.entries.count, initialCount + 1)
    }

    func test_add_dedup_same_path() {
        let store = LauncherStore()
        let path = "/Applications/EdgeLauncher.app"
        store.add(url: URL(fileURLWithPath: path))
        let after = store.entries.count
        store.add(url: URL(fileURLWithPath: path))
        XCTAssertEqual(store.entries.count, after)
    }

    func test_remove_drops_entry() {
        let store = LauncherStore()
        let entry = LauncherEntry(name: "Temp", bundleURL: "/tmp/Temp.app")
        store.entries.append(entry)
        store.remove(entry)
        XCTAssertFalse(store.entries.contains(entry))
    }
}
```

- [ ] **Step 5: 빌드 + 테스트**

`bash scripts/test.sh 2>&1 | grep -E "passed|FAILED" | tail -20`

- [ ] **Step 6: Commit**

```bash
git add EdgeLauncherTests EdgeLauncher/Modules/Messenger/MessengerView.swift
git commit -m "test: cover Phase 2 modules, Discord parser, LauncherStore"
```

---

## Task 18: 최종 빌드·배포·검수 + README 갱신

**Files:**
- Modify: `EdgeLauncher/README.md`
- Modify: `EdgeLauncher/GUIDE.md`
- Modify: `EdgeLauncher/VERSION` (0.1.0 → 0.2.0)

- [ ] **Step 1: VERSION 갱신**

```bash
echo "0.2.0" > VERSION
```

또한 `project.pbxproj` 의 MARKETING_VERSION 도 0.2.0 으로:

```bash
sed -i.bak 's/MARKETING_VERSION = 0.1.0/MARKETING_VERSION = 0.2.0/g' EdgeLauncher.xcodeproj/project.pbxproj
rm EdgeLauncher.xcodeproj/project.pbxproj.bak
```

- [ ] **Step 2: README/GUIDE 갱신**

README의 "특징" 섹션과 GUIDE의 "탭별 사용법", "단축키" 섹션을 새 기능에 맞춰 갱신:
- 사이드바 터치 스크롤
- Cmd+1..N 단축키, Cmd+R 새로고침
- 설정 > 탭에서 모듈 표시 토글
- 사이드바 드래그&드롭 순서 변경
- 풀스크린 chrome 자동 숨김

(이 단계는 실제 항목들을 인라인으로 작성 — 새 섹션을 더하고 v0.1.0 → v0.2.0 표시.)

- [ ] **Step 3: 최종 deploy**

```bash
make deploy
```

- [ ] **Step 4: 수동 검수 체크리스트**

다음 항목을 한 번씩 확인:
1. 사이드바에 모듈 6개 표시. 터치 드래그 스크롤 OK.
2. Cmd+1..6 으로 탭 전환.
3. Cmd+R 시 활성 WebView reload.
4. 설정 > 탭에서 모듈 숨김 토글 → 사이드바에서 사라짐.
5. 사이드바 모듈 드래그&드롭 → 순서 변경. 재실행 시 순서 유지.
6. WebView 처음 활성화될 때만 로드 (메모리 모니터에서 확인).
7. Monitor 비활성 시 ProcessStats Timer 멈춤 (Activity Monitor 에서 sh 자식 프로세스 사라짐).
8. 위치 권한 거부 후 노란 ErrorBanner 표시.
9. 풀스크린 진입 + 3초 후 헤더·사이드바 fade-out. 마우스 이동 시 fade-in.
10. 전체 단위 테스트 통과 (22개 이상).

- [ ] **Step 5: 최종 Commit**

```bash
git add VERSION EdgeLauncher.xcodeproj/project.pbxproj README.md GUIDE.md
git commit -m "chore: bump version to 0.2.0 with polish release notes"
```

---

## 완료 기준

- 18개 Task 모든 step 체크박스 완료
- `bash scripts/test.sh` 전체 PASS (22개 이상)
- 수동 검수 체크리스트 10개 항목 통과
- VERSION 0.2.0
- Phase 3 신기능(메뉴바, 자동 순환 등)은 별도 spec/plan으로 분리
