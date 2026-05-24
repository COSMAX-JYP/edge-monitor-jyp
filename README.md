# EdgeLauncher

Corsair Xeneon Edge(14.5", 2560x720, 32:9, 멀티터치)를 위한 macOS 네이티브 런처. 좌측 사이드바에서 모듈을 골라 32:9 풀폭으로 사용한다.

> 🚀 설치 → [INSTALL.md](INSTALL.md)
> 📖 사용법·트러블슈팅 → [GUIDE.md](GUIDE.md)
> 🏗️ 디자인 spec → [docs/superpowers/specs/](docs/superpowers/specs/)
> 🛠️ 구현 plan → [docs/superpowers/plans/](docs/superpowers/plans/)

---

## v0.4.0 변경 사항 (SlidePad 칸반 릴리스)

- **SlidePad 칸반 패널** — Cmd+Shift+K 전역 단축키로 우측 가장자리에서 슬라이드+페이드 인되는 NSPanel. 다른 앱 활성 상태에서도 그대로 호출, non-activating 으로 원 앱 포커스 유지.
- 메인 윈도우의 Kanban 모듈과 동일한 `KanbanStore` 를 공유 — 양방향 즉시 반영. UI 상태(검색·편집·드래그)는 패널과 메인이 독립.
- 자동 숨김: 외부 클릭 / Esc / windowDidResignKey (4단계 가드). 카드 편집 시트, 라벨 매니저 등 시트 열려 있으면 시트만 닫고 패널 유지. 핀 토글로 자동 숨김 차단.
- 한글 IME 조합 중 외부 클릭 grace, sleep/wake 후 hotkey 재바인딩, 디스플레이 reconfig 시 frame 재계산.
- Settings → "SlidePad 칸반" 탭: 폭 / 애니메이션 길이 / 타깃 디스플레이 (마우스/메인/UUID 고정) / 자동 숨김·Esc·핀 토글.
- View 메뉴 "SlidePad 칸반 토글" — Carbon hotkey 등록 실패 시 fallback.
- 단위 테스트 35+ 추가 (Settings/HotKeyRegistrar/Carbon dispatcher/HotKey wrapper/Controller/AutoHide/Store sharing).
- 부수 fix: CorsairHIDCapture 의 접근성/입력 모니터링 prompt 가 빌드마다 3~4개 동시에 뜨던 spam 해결 (사전 IOHIDCheckAccess + AXIsProcessTrusted 가드).

상세 spec/plan: `docs/superpowers/specs/2026-05-24-edgelauncher-slidepad-kanban-design.md`, `docs/superpowers/plans/2026-05-24-edgelauncher-slidepad-kanban-plan.md`. 수동 QA 체크리스트: `EdgeLauncher/docs/qa-slidepanel.md`.

## v0.3.0 변경 사항 (infrastructure 릴리스)

- `CommandRouter` 도입: 활성 모듈 기반 키보드 단축키 라우팅. Cmd+N/E/F/Delete/R 등 표준 명령을 모듈에 dispatch.
- `PermissionService` 도입: Calendar(EventKit) / Accessibility / Automation 권한 통합. `notDetermined/denied/restricted/writeOnly/authorized` 5상태 명시.
- `AtomicJSONStore<T>` 도입: temp + rename + 백업 회전 + 스키마 버전 envelope + debounced save / explicit flush. 손상 파일 자동 복구.
- `EdgeModule` 프로토콜 확장: `commandHandler`, `requiredPermissions`, `willTerminate()` 선택 훅.
- `PermissionPromptView` 공통 onboarding UI.
- Info.plist 키 가이드 (`Core/Build/InfoPlistRecipes.md`) — `INFOPLIST_KEY_*` build setting 사용.
- 단위 테스트 30+ 추가 (CommandRouter / PermissionService / AtomicJSONStore / DebouncedSaver).
- 다운스트림 plan (Timeline / Kanban / StreamDeck) 의 Phase 1 시작에 필요한 공통 인프라 완성.

## v0.2.0 변경 사항 (polish 릴리스)

- 사이드바 손가락 panning 지원 (`TouchScrollContainer` + `NSPanGestureRecognizer`)
- 사이드바 모듈 drag&drop 으로 순서 변경, 순서는 UserDefaults에 영속
- 설정 > 탭 에서 모듈 표시 토글
- Cmd+1..9 탭 단축키 / Cmd+R 새로고침
- 풀스크린 시 헤더·사이드바 3초 idle 자동 숨김
- 모듈 lifecycle 훅: Monitor/Widget Timer가 비활성 탭에서 자동 정지
- WKWebView lazy load: 처음 활성화될 때만 인스턴스화
- ErrorBanner 통합 에러 피드백 + os.Logger 기반 로깅
- Phase 2 모듈 4개 메타데이터 + Discord parser + LauncherStore 테스트 추가 (28개)

---

## 특징

- **좌측 사이드바 + 32:9 컨텐츠** — 155 px 폭의 큰 터치 타겟 사이드바와 풀폭 컨텐츠 영역. 손가락 panning 지원.
- **YouTube 탭** — WKWebView 임베드, 더블탭 좌/우 10초 점프, HTML5 풀스크린
- **YouTube Music 탭** — 미디어 키 연동, macOS Now Playing 위젯 호환
- **Discord (Inbox) 탭** — 웹앱 임베드 + 미읽음 카운트 사이드바 빨간 배지
- **Monitor 탭** — CPU/RAM 가로 sparkline + CPU/Memory/Energy/Disk Top 10 (우클릭 SIGTERM/SIGKILL)
- **Widgets 탭** — glow 시계 + Open-Meteo 날씨 + macOS Calendar (Outlook 포함) + Reminders
- **Launcher 탭** — 앱 추가/삭제 가능한 그리드, 클릭으로 실제 실행
- **SlidePad 칸반** — Cmd+Shift+K 글로벌 단축키로 화면 우측 가장자리에서 슬라이드되는 NSPanel. 메인 윈도우의 Kanban 데이터와 동일 store 공유 (양방향 즉시 반영), non-activating 으로 다른 앱 활성 유지.
- **Xeneon Edge 자동 감지** — `NSScreen` 변경 감시, 자동 이동·풀스크린 (설정 토글)
- **모듈화 아키텍처** — `EdgeModule` 프로토콜 + lifecycle 훅으로 새 탭을 모듈로 추가

---

## 한 줄 설치

```bash
cd EdgeLauncher
make install run
```

- macOS 14 Sonoma 이상, Xcode 15+ 필요
- 첫 빌드 1–3 분, 이후 캐시로 수 초

자세한 절차·트러블슈팅은 [INSTALL.md](INSTALL.md).

---

## Make 타깃

| 명령 | 설명 |
|---|---|
| `make help` | 사용 가능한 타깃 목록 |
| `make test` | 단위 테스트 실행 (xcodebuild test) |
| `make build` | Release 빌드 |
| `make install` | 빌드 + `~/Applications` 에 설치 |
| `make run` | 설치된 앱 실행 |
| `make deploy` | 빌드 + 재설치 + 실행 (한 번에) |
| `make icon` | AppIcon PNG 재생성 (Python Pillow 필요) |
| `make clean` | `build/` 디렉토리 삭제 |

---

## 디렉토리 구조

```
EdgeLauncher/
├── App/                       # @main, AppEnvironment
├── Core/
│   ├── Module/                # EdgeModule 프로토콜, ModuleRegistry
│   ├── Display/               # XeneonDisplayService (2560x720 감지)
│   ├── Window/                # EdgeWindowController (이동·풀스크린)
│   └── Media/                 # NowPlayingBridge (WebKit 기본 동작 의존)
├── UI/                        # RootView, Sidebar, TabRouter, 헤더 바
├── Modules/
│   ├── YouTube/               # WKWebView + 더블탭 점프 JS
│   └── YouTubeMusic/          # WKWebView
├── Settings/                  # SettingsView (자동 이동/풀스크린 토글)
└── Assets.xcassets/AppIcon.appiconset/

EdgeLauncherTests/             # 14 개 단위 테스트
scripts/
├── test.sh                    # xcodebuild test 헬퍼
├── deploy.sh                  # 빌드+재설치+실행
└── make-icon.py               # AppIcon PNG 10 size 생성
docs/superpowers/              # spec, plan
VERSION                        # 현재 0.1.0
Makefile
```

---

## 버전 표시

앱 상단 헤더 바에 현재 버전(`Info.plist`의 `CFBundleShortVersionString`)이 항상 표시된다. `make install` 시 `MARKETING_VERSION` 으로 주입.

---

## 로드맵 (Phase 2)

| 모듈 | 32:9 적합도 |
|---|---|
| 시스템 모니터 (CPU/GPU/RAM 가로 시계열) | 매우 높음 |
| 위젯 대시보드 (시계/날씨/캘린더/할일) | 높음 |
| 메신저 사이드 패널 (Slack/Discord/Mail) | 중간 |
| 런처 (클립보드 히스토리, AI 채팅) | 높음 |
| 앰비언트 (디지털 액자, 비주얼라이저) | 매우 높음 |

각 모듈은 독립 spec/plan 으로 분리하여 순차 개발.

---

## 라이선스

개인 사용 빌드. 외부 배포 시 별도 코드 서명·공증·라이선스 검토 필요.

Designed by jyp.
