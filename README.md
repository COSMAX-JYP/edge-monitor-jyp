# EdgeLauncher

Corsair Xeneon Edge(14.5", 2560x720, 32:9, 멀티터치)를 위한 macOS 네이티브 런처. 좌측 사이드바에서 탭을 전환하여 32:9 풀폭으로 사용한다.

## 요구사항

- macOS 14 Sonoma 이상
- Xcode 15+
- Swift 5.9+

## 빌드 및 실행

```bash
open EdgeLauncher.xcodeproj
# Xcode에서 Cmd+R
```

## 테스트

```bash
bash scripts/test.sh
```

> macOS 26 베타 환경의 CodeSign 이슈 우회를 위해 `CODE_SIGNING_ALLOWED=NO` 옵션을 사용한다.

## MVP 모듈

| 탭 | 설명 |
|---|---|
| YouTube | youtube.com 임베드, 더블탭 좌/우로 10초 점프 |
| Music | music.youtube.com 임베드, 미디어 키 연동 |

## 아키텍처 요약

- `EdgeModule` 프로토콜과 `ModuleRegistry`로 탭을 모듈화
- 좌측 사이드바에 모듈이 자동 등록
- `XeneonDisplayService`가 2560x720 디스플레이를 자동 감지
- 사이드바 하단 "Edge로 이동" 버튼으로 윈도우 이동
- WKWebView 기반 미디어 임베드 (쿠키 영속화로 로그인 유지)

자세한 설계는 `docs/superpowers/specs/2026-05-15-xeneon-edge-launcher-design.md` 참조.

## 다음 단계 (Phase 2)

- 시스템 모니터 (CPU/GPU/RAM/네트워크 가로 시계열)
- 위젯 대시보드 (시계/날씨/캘린더/할일)
- 메신저 사이드 패널
- 런처/AI 채팅
- 앰비언트 (디지털 액자, 비주얼라이저)

## 디렉토리 구조

```
EdgeLauncher/
├── App/                    # 앱 엔트리, AppEnvironment
├── Core/
│   ├── Module/             # EdgeModule, ModuleRegistry
│   ├── Display/            # XeneonDisplayService
│   ├── Window/             # EdgeWindowController
│   └── Media/              # NowPlayingBridge (스텁)
├── UI/                     # Sidebar, RootView, TabRouter, Components
├── Modules/
│   ├── YouTube/
│   └── YouTubeMusic/
├── Settings/
└── Assets.xcassets

EdgeLauncherTests/          # 단위 테스트
scripts/test.sh             # xcodebuild test 헬퍼
docs/superpowers/           # 설계 spec, 구현 plan
```

## 실기기 검수 체크리스트

Xeneon Edge에 연결한 상태에서 다음 항목을 확인한다.

1. 앱 실행 시 사이드바와 YouTube 탭이 보인다
2. Music 탭 클릭 시 music.youtube.com이 로딩된다
3. Sidebar의 "Edge로 이동" 버튼이 활성 상태로 표시된다
4. 클릭 시 윈도우가 Xeneon Edge로 이동한다
5. 설정에서 자동 이동을 켜고 재실행 시 자동 이동된다
6. YouTube 영상에서 더블탭 좌/우 10초 점프가 동작한다
7. YouTube Music 재생 중 키보드 미디어 키가 동작한다
8. 제어센터 Now Playing 위젯에 곡 정보가 보인다
9. 풀스크린 토글이 정상 동작한다
10. 로그아웃 후 재시작 시 로그인이 유지된다

검수 중 발견된 이슈는 `docs/superpowers/specs/2026-05-15-xeneon-edge-launcher-design.md` 의 "14. 미해결 사항" 섹션에 추가한다.
