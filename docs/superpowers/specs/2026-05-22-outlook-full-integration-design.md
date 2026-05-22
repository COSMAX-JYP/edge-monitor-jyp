# Outlook 풀 통합 + 세로 타임라인 디자인

작성일: 2026-05-22
작성자: EdgeLauncher Timeline 작업 담당
승인: 본인 (브레인스토밍 결과 모두 권장사항 채택)

## 1. 배경 및 목표

현재 EdgeLauncher Timeline 모듈은 EventKit(Apple Calendar) + Outlook(Microsoft Graph 일부)을 통합 표시한다. 사용자 요청 사항:

1. 빈 수직 공간이 많은 가로 타임라인 → 세로 타임라인(Apple/Google 스타일)으로 전환
2. 일정 작성 시 참석자 초대 지원
3. Outlook 의 모든 일반적 기능을 지원 (참석자, Teams 온라인 미팅, 반복, 알림, 카테고리, 중요도, 응답, findMeetingTimes 등)

본 디자인은 다음 마일스톤으로 분할 구현한다.

## 2. 마일스톤

| 마일스톤 | 내용 | 결과물 |
|---|---|---|
| **M1** | 세로 타임라인 + Day/Week/Month 뷰 모드 | 새 레이아웃 + 뷰 전환 + 키보드 단축키 |
| **M2** | 캘린더 사이드바 + 토글 + 색상 | `CalendarVisibilityStore` + 사이드바 UI |
| **M3** | 참석자 초대 + Graph People 자동완성 + Teams 토글 | `AttendeeSearchService` + `AttendeePickerView` |
| **M4** | 알림 · 반복 · 중요도 · 표시상태 · 민감도 · 응답 | `EventEditorSheet` 확장 + Graph DTO 확장 + accept/decline 액션 |
| **M5** | findMeetingTimes · free/busy · HTML 본문 · 첨부 · 전달 · 취소 | `ScheduleService` + HTML 뷰어 + 첨부 UI |

각 마일스톤은 별도 commit/PR. 빌드 + 배포 + 검증 후 다음 단계.

## 3. 아키텍처

```
AppEnvironment
├── EKEventStore (shared)
├── MSALAuthService (custom OAuth, 자체 keychain)
├── CalendarVisibilityStore (신규)      ← M2
├── AttendeeSearchService (신규)        ← M3
├── ScheduleService (신규)              ← M5
└── TimelineCalendarModule
    └── TimelineViewModel
        ├── AggregatingCalendarProvider
        │   ├── EventKitProvider
        │   └── GraphCalendarProvider (확장)
        │       ├── attendees 지원
        │       ├── recurrence 지원
        │       ├── isOnlineMeeting/onlineMeeting 지원
        │       ├── importance/sensitivity/showAs/categories 지원
        │       └── accept/decline/tentativelyAccept 액션
        └── 뷰
            ├── TimelineCalendarView (라우터)
            ├── DayView (세로, 신규)
            ├── WeekView (세로 7컬럼, 신규)
            ├── MonthView (그리드, 신규)
            ├── EventEditorSheet (대폭 확장)
            ├── AttendeePickerView (신규)
            └── EventDetailPanel (응답 버튼 추가)
```

## 4. M1: 세로 타임라인 + 뷰 모드

### 4.1 데이터 모델

```swift
enum TimelineViewMode: String, CaseIterable, Codable, Sendable {
    case day, week, month
    var displayName: String { ... }
}

struct VerticalRulerLayout {
    let startHour: Int      // 0
    let endHour: Int        // 24
    let pixelsPerHour: CGFloat   // 60
    var totalHeight: CGFloat { CGFloat(endHour - startHour) * pixelsPerHour }
    func y(for date: Date, on day: Date) -> CGFloat
    func height(from: Date, to: Date, on day: Date) -> CGFloat
    func date(at y: CGFloat, on day: Date) -> Date
}
```

`EventLayoutEngine`은 그대로 사용. 세로 컬럼 안에서 동시에 있는 일정들 → column 분할 알고리즘 동일.

### 4.2 뷰 구성

**DayView**: 좌측에 시간 레이블 (col 50px) + 우측에 일정 영역 (남은 너비). 시간 마디 매 시간(60px). 종일 일정은 상단 별도 밴드.

**WeekView**: 좌측 시간 레이블 + 7개 컬럼 (각 컬럼 너비 균등). 각 컬럼은 day view의 축소판. 헤더 행에 요일 + 날짜 + 오늘 강조.

**MonthView**: 6주 × 7일 그리드. 각 셀: 날짜 숫자 + 최대 3개 일정 미리보기 + "+N more" 토글.

### 4.3 키보드 단축키

| 키 | 동작 |
|---|---|
| `⌘1` | Day view |
| `⌘2` | Week view |
| `⌘3` | Month view |
| `⌘←` / `⌘→` | 이전/다음 (단위는 현재 뷰 모드 따라) |
| `⌘T` | 오늘 |
| `⌘N` | 새 일정 |
| `⌘R` | 새로고침 |

### 4.4 자동 스크롤

DayView/WeekView 진입 시 현재 시각이 보이도록 자동 스크롤. 오늘이 아니면 첫 일정 시각 or 09:00 으로.

### 4.5 키보드 + 마우스 인터랙션

- 더블 클릭: 빈 시간 → 새 일정 (시작 시각 자동 추정, 15분 단위 스냅)
- 클릭: 일정 → EventDetailPanel
- WeekView의 컬럼 헤더 클릭: 해당 날짜로 Day view 이동
- MonthView의 셀 클릭: 해당 날짜로 Day view 이동

### 4.6 시간대 처리

모든 시각은 사용자 로컬 타임존(`TimeZone.current`)으로 표시. Graph 응답 파싱 시 timezone 정보 활용. Apple EventKit 은 기본적으로 로컬 타임존.

## 5. M2: 캘린더 사이드바

### 5.1 데이터 모델

```swift
@MainActor
final class CalendarVisibilityStore: ObservableObject {
    @Published var visibleIds: Set<String>     // 표시할 calendar id 들
    @Published var customColors: [String: String]   // id -> hex 색상 override
    private let defaults: UserDefaults
    func toggle(_ id: String)
    func setColor(_ id: String, hex: String?)
}
```

UserDefaults 키: `app.timeline.visibleCalendars` (Set<String> → [String] 인코딩), `app.timeline.calendarColors`.

기본값: 사용 가능한 모든 캘린더 표시.

### 5.2 UI

Timeline 뷰 좌측 하단에 토글 가능한 사이드바 (~250px 너비, ⌘B 로 토글). 항목:

```
캘린더
├── Apple
│   ├── ● Calendar
│   ├── ● Birthdays
│   └── ● Korean Holidays
└── Outlook (parkjy@cosmax.com)
    ├── ● Calendar
    └── ● Shared Calendar
```

각 항목 좌측에 컬러 점(클릭 → 색상 피커), 우측에 체크박스. 체크 해제하면 해당 캘린더 일정이 타임라인에서 숨김.

`AggregatingCalendarProvider.availableCalendars()` 결과를 받아 표시. `fetchEvents` 결과는 `visibleIds` 로 필터.

## 6. M3: 참석자 초대 + Teams 미팅

### 6.1 AttendeeSearchService

```swift
@MainActor
final class AttendeeSearchService {
    private let auth: MSALAuthService
    func searchPeople(query: String) async throws -> [Person]
    // GET /me/people?$search="query"&$select=displayName,scoredEmailAddresses,jobTitle,department
}

struct Person: Identifiable, Hashable {
    let id: String
    let displayName: String
    let email: String          // primary scored email
    let jobTitle: String?
    let department: String?
}
```

캐싱: 입력당 200ms debounce, 직전 10건 결과 LRU 메모리 캐시.

### 6.2 AttendeePickerView

EventEditorSheet 내 "참석자" 섹션:

```
참석자
┌──────────────────────────────────────────┐
│ [김지영 (kjy@cosmax.com) ✕] [+]          │
│ [+ 사람 추가] ← 클릭 시 검색 팝오버 표시   │
└──────────────────────────────────────────┘
[ ] 응답 요청     [ ] 새 시간 제안 허용
```

각 참석자 카드: 이름 + 이메일 + 응답 상태(생성 후) + 제거 X.

검색 팝오버: 입력 → debounced search → 결과 목록 → 클릭 시 추가. 자유 이메일 입력도 허용 (검색 미스 시 "use 'foo@bar.com' as is" 옵션).

### 6.3 GraphCalendarProvider 확장

`GraphEvent` DTO 확장 (이미 attendees 일부 디코드 중이지만 응답 ResponseStatus 정확히 처리). `GraphEventInput` 에 attendees 추가:

```swift
private struct GraphEventInput: Encodable {
    let subject: String
    let body: GraphEventBody?
    let start: GraphDateTime
    let end: GraphDateTime
    let location: GraphLocation?
    let isAllDay: Bool
    let attendees: [GraphAttendeeInput]?      // 신규
    let isOnlineMeeting: Bool?                // 신규
    let onlineMeetingProvider: String?        // "teamsForBusiness"
    let responseRequested: Bool?
    let allowNewTimeProposals: Bool?
}

private struct GraphAttendeeInput: Encodable {
    let emailAddress: GraphEmailAddress
    let type: String   // "required" | "optional" | "resource"
}
```

### 6.4 EventDraft 확장

`Attendee` 모델 이미 존재. `EventDraft` 에 추가:

```swift
struct EventDraft {
    // ... existing
    var attendees: [Attendee]
    var isOnlineMeeting: Bool
    var responseRequested: Bool
    var allowNewTimeProposals: Bool
}
```

### 6.5 Teams 토글

EventEditorSheet 에 "Teams 미팅" 토글 추가. 활성화 → `isOnlineMeeting=true` + `onlineMeetingProvider="teamsForBusiness"`. Graph 응답으로 `joinUrl` 받아 `event.url` 에 저장. EventDetailPanel 의 "Teams 회의 열기" 링크가 자동 동작.

## 7. M4: 알림 · 반복 · 중요도 · 표시상태 · 민감도 · 응답

### 7.1 EventDraft 확장

```swift
struct EventDraft {
    // ... 기존 + M3 확장
    var reminderMinutesBeforeStart: Int?         // nil = 알림 없음
    var recurrence: RecurrencePattern?           // nil = 단발
    var importance: Importance                   // .low/.normal/.high
    var sensitivity: Sensitivity                 // .normal/.personal/.private/.confidential
    var showAs: ShowAs                           // .free/.tentative/.busy/.oof/.workingElsewhere
    var categories: [String]                     // 사용자 정의 카테고리
}

enum RecurrencePattern: Codable {
    case daily(interval: Int, end: RecurrenceEnd)
    case weekly(interval: Int, weekdays: Set<Weekday>, end: RecurrenceEnd)
    case monthly(interval: Int, dayOfMonth: Int, end: RecurrenceEnd)
    case yearly(interval: Int, month: Int, day: Int, end: RecurrenceEnd)
    case custom(rrule: String)
}

enum RecurrenceEnd: Codable {
    case never
    case after(occurrences: Int)
    case onDate(Date)
}
```

### 7.2 UI 섹션 추가 (EventEditorSheet)

```
알림
  [ 30분 전 ▼ ]   알림 없음/0/5/10/15/30/60분/하루전/없음

반복
  [ 반복 안 함 ▼ ]   안 함/매일/매주/매월/매년/사용자정의
  └─ 매주 선택 시 [ 월 화 ⊕ 수 목 ⊕ 금 토 일 ] 요일 다중선택
  └─ 종료 [ 영원 ▼ ]   영원/N회 후/날짜

중요도   [ 일반 ▼ ]   낮음/일반/높음
표시상태 [ 바쁨 ▼ ]   여유/잠정/바쁨/부재중/외부근무
민감도   [ 일반 ▼ ]   일반/개인/비공개/기밀
카테고리 [ +Tag1 +Tag2 ⊕ ]
```

### 7.3 응답 액션 (EventDetailPanel)

Outlook 이벤트에 한해 (`event.source == .outlook`) "수락 / 잠정 / 거절" 버튼 표시. 클릭 시 사유 입력 sheet → Graph `/events/{id}/accept` `/tentativelyAccept` `/decline` POST + `comment` body.

```swift
extension GraphCalendarProvider {
    func acceptEvent(_ event: TimelineEvent, comment: String?, sendResponse: Bool) async throws
    func tentativelyAcceptEvent(_ event: TimelineEvent, comment: String?, sendResponse: Bool) async throws
    func declineEvent(_ event: TimelineEvent, comment: String?, sendResponse: Bool) async throws
}
```

## 8. M5: 고급 — findMeetingTimes · 자유시간 · HTML · 첨부 · 전달 · 취소

### 8.1 ScheduleService

```swift
@MainActor
final class ScheduleService {
    private let auth: MSALAuthService
    func freeBusy(emails: [String], from: Date, to: Date) async throws -> [String: [BusySlot]]
    func findMeetingTimes(attendees: [String], minDuration: TimeInterval, timeWindow: DateInterval) async throws -> [MeetingTimeSuggestion]
}

struct BusySlot { let start: Date; let end: Date; let status: String }
struct MeetingTimeSuggestion { let start: Date; let end: Date; let confidence: Double; let attendees: [AttendeeAvailability] }
```

### 8.2 일정 작성 시 free/busy 오버레이

EventEditorSheet 의 시작 시간 변경 시, 참석자가 있다면 백그라운드로 getSchedule 호출 → DatePicker 옆에 빨간 막대로 충돌 시각 시각화.

### 8.3 findMeetingTimes 통합

EventEditorSheet 의 "AI 시간 제안" 버튼 → `ScheduleService.findMeetingTimes` 호출 → 상위 3-5 제안을 카드로 표시 → 클릭 시 start/end 자동 입력.

### 8.4 HTML 본문 에디터

`AttributedString` + `TextEditor` 로 단순 텍스트 + 기본 마크다운 입력 지원. 저장 시 `body.contentType="text"` 그대로 또는 마크다운 → HTML 변환 후 `contentType="html"`. 표시는 `AttributedString` 으로 렌더.

세부 마크다운 → HTML 변환 단순화: Swift Foundation 의 `AttributedString(markdown:)` 사용.

### 8.5 첨부 파일

EventDetailPanel 에 첨부 목록 표시. 첨부 추가는 `NSOpenPanel` 로 파일 선택 → multipart POST `/events/{id}/attachments`. 3MB 초과 시 large attachment session 필요 (M5 범위에서 제외, 3MB 이하만).

### 8.6 전달

EventDetailPanel "전달" 버튼 → 새 수신자 선택 (AttendeePickerView) + 메시지 입력 → POST `/events/{id}/forward`.

### 8.7 취소

EventDetailPanel "취소(참석자에게 알림)" 버튼 (organizer 일 때만) → 메시지 입력 → POST `/events/{id}/cancel`. 단순 삭제와 구분.

## 9. 데이터 흐름 변경 요약

- `TimelineViewModel.events` 는 그대로. 단, `CalendarVisibilityStore.visibleIds` 와 join 해서 표시 필터.
- 새 일정 작성 시 `editorDraft.attendees` 채워 `provider.saveEvent` 호출 → Graph `attendees` 필드 포함.
- 응답 액션은 새 메서드들로 처리. 응답 후 자동 reload.
- find/freeBusy 는 별도 서비스에서 비동기 수행, 결과는 UI 오버레이로 표시.

## 10. 권한 추가 요청 (M3 이상)

`Calendars.ReadWrite` 와 `Calendars.ReadWrite.Shared` 외에 다음 권한 필요:

- **`People.Read`** (M3): `/me/people` 검색
- **`Calendars.Read`** + **freeBusy** 호환 — 이미 `Calendars.ReadWrite` 에 포함

`People.Read` 는 Delegated 권한이며 사용자 동의 가능. 인프라팀 admin consent 재확인 필요.

## 11. 테스트 전략

- 단위 테스트
  - `VerticalRulerLayout`: y/height/date 변환 (기존 `TimeRulerLayoutTests` 본떠 새 `VerticalRulerLayoutTests`)
  - `EventLayoutEngine`: 그대로 (이미 충돌 분할 알고리즘 검증)
  - `RecurrencePattern` Codable round-trip
  - `CalendarVisibilityStore`: persistence + toggle
  - `GraphCalendarProvider.saveEvent` 의 attendees/recurrence/isOnlineMeeting body 인코딩 (스텁 URLSession)
- 수동 검증 (사용자 본인)
  - 본인 계정으로 로그인 → 본인 일정 표시
  - 새 일정 생성 + 참석자 초대 → Outlook 모바일 앱에서 확인
  - 반복 일정 생성 → 다음 날 일정 표시
  - 응답 액션 → Outlook 측에서 상태 변경 반영
  - Teams 미팅 → joinUrl 동작

## 12. 비기능 요구사항

- 빌드/배포는 기존 `make deploy` 흐름 유지 (CODE_SIGNING_ALLOWED=NO + 자체 codesign)
- TCC 권한 안정성: 코드 서명 identity 변경 안 함
- 추가 entitlement 불필요 (keychain-access-groups 제외 상태 유지)
- macOS 14+ 타겟 유지

## 13. 아웃 오브 스코프

- macOS 13 이하 호환
- 다중 계정 (한 사용자가 여러 MS365 계정 로그인) — 현재 단일 계정
- 캘린더 새 생성/삭제 (Graph 는 지원하나 UI 복잡)
- 그룹 캘린더(`/groups/{id}/calendar`)
- 대용량 첨부 (>3MB)
- 시리즈 예외 편집 UI (단일 occurrence 만 수정) — 단발/전체만 지원
- 외부 사용자 권한 부여(공유) UI

## 14. 작업 순서 (다음 단계)

1. M1 구현 → 빌드/검증/배포
2. M2 구현 → 빌드/검증/배포
3. M3 구현 → 빌드/검증/배포
4. M4 구현 → 빌드/검증/배포
5. M5 구현 → 빌드/검증/배포

각 마일스톤은 단독 동작 가능한 단위. 중단 시점에 안정 상태.
