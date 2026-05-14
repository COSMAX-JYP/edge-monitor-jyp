# EdgeLauncher

Corsair Xeneon Edge(14.5", 2560x720, 32:9, 멀티터치)를 위한 macOS 네이티브 런처. 좌측 사이드바에서 모듈을 골라 32:9 풀폭으로 사용한다.

> 🚀 설치 → [INSTALL.md](INSTALL.md)
> 📖 사용법·트러블슈팅 → [GUIDE.md](GUIDE.md)
> 🏗️ 디자인 spec → [docs/superpowers/specs/2026-05-15-xeneon-edge-launcher-design.md](docs/superpowers/specs/2026-05-15-xeneon-edge-launcher-design.md)
> 🛠️ 구현 plan → [docs/superpowers/plans/2026-05-15-xeneon-edge-launcher.md](docs/superpowers/plans/2026-05-15-xeneon-edge-launcher.md)

---

## 특징

- **좌측 사이드바 + 32:9 컨텐츠** — 110 px 폭의 큰 터치 타겟 사이드바와 풀폭 컨텐츠 영역
- **YouTube 탭** — WKWebView 임베드, 더블탭 좌/우 10초 점프, 자동재생/PiP/풀스크린
- **YouTube Music 탭** — 미디어 키 연동, macOS Now Playing 위젯 호환
- **Xeneon Edge 자동 감지** — `NSScreen` 변경 감시, 사이드바 ⇨ 버튼 한 번으로 윈도우 이동
- **자동 이동/풀스크린** — 설정에서 켜면 앱 실행 시 자동으로 Edge 풀스크린
- **모듈화 아키텍처** — `EdgeModule` 프로토콜로 새 탭을 모듈로 추가 (Phase 2 로드맵)

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
