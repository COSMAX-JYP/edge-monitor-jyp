# EdgeLauncher 설치 가이드

Corsair Xeneon Edge 전용 macOS 런처. 개인 사용 목적 빌드.

## 요구사항

| 항목 | 버전 |
|---|---|
| macOS | 14 Sonoma 이상 |
| Xcode | 15 이상 |
| Swift | 5.9 이상 |
| Python | 3.x (아이콘 재생성 시) |

## 한 줄 설치

```bash
cd EdgeLauncher
make install run
```

- `make install` 은 Release 빌드 + `~/Applications/EdgeLauncher.app` 에 복사.
- `make run` 은 설치된 앱 실행.

처음 빌드는 1~3분 걸린다. 두 번째부터는 캐시로 수 초 내.

## 상세 단계

```bash
# 1. 의존성 확인
make help

# 2. 단위 테스트 (선택)
make test

# 3. Release 빌드
make build

# 4. ~/Applications 에 설치
make install

# 5. 실행
make run

# 또는 위 4 단계를 한 번에
make deploy
```

## 자주 발생하는 이슈

### CodeSign 실패 (macOS 26 베타 환경)

기본적으로 `CODE_SIGNING_ALLOWED=NO` 옵션이 들어가 있어 우회한다. Release 빌드의 코드 서명 이슈는 자동으로 비활성화된다.

### "확인할 수 없는 개발자" 경고

unsigned 빌드라 macOS Gatekeeper 가 막을 수 있다. 설치 스크립트가 `xattr -dr com.apple.quarantine` 으로 quarantine 속성을 제거한다. 그래도 막히면:

1. Finder 에서 `~/Applications/EdgeLauncher.app` 우클릭 → 열기
2. "열기" 한 번 확인

### App Sandbox 네트워크 차단

YouTube 또는 YouTube Music 페이지가 비어있으면 sandbox 네트워크 권한 문제.

Xcode > Project > Targets > EdgeLauncher > Signing & Capabilities > **App Sandbox** > Network > Outgoing Connections (Client) 체크.

또는 App Sandbox capability 자체를 삭제하면 권한 제약이 없어진다.

### Xeneon Edge 미감지

`XeneonDisplayService` 가 해상도 2560x720 ±4px 기준으로 감지한다. HiDPI 모드의 논리 해상도가 다르면 감지가 안 될 수 있다. 사이드바 하단 "Edge로 이동" 버튼이 비활성 상태로 표시된다.

`xrandr` 대신 `System Information.app > Graphics/Displays` 에서 실제 논리 해상도 확인.

## 아이콘 재생성

```bash
make icon
```

`scripts/make-icon.py` 가 1024 PNG 와 모든 사이즈 변형을 `AppIcon.appiconset/` 에 다시 생성한다. Pillow 가 필요하다: `python3 -m pip install Pillow`.

## 접근성 + 입력 모니터링 권한 (터치 → 합성 클릭)

Edge 터치를 Edge 디스플레이의 정확한 좌표로 합성 클릭하려면 두 가지 권한이 모두 필요합니다.

| 권한 | 용도 |
|---|---|
| 입력 모니터링 (Input Monitoring) | `IOHIDManagerOpen(SeizeDevice)` 로 터치 패널 원시 입력을 점유 |
| 접근성 (Accessibility) | `CGEvent.post` 로 합성 클릭 이벤트를 시스템 이벤트 탭에 주입 |

### 권한 부여 절차

1. 시스템 설정 → 개인정보 보호 및 보안 → **접근성** → `+` → EdgeLauncher.app 추가 후 체크.
2. 시스템 설정 → 개인정보 보호 및 보안 → **입력 모니터링** → `+` → EdgeLauncher.app 추가 후 체크.
3. EdgeLauncher 를 완전 종료 후 재시작.

설치 위치는 환경에 따라 다음 중 하나입니다.

- `~/Applications/EdgeLauncher.app` (`make install` 결과)
- `~/Library/Developer/Xcode/DerivedData/EdgeLauncher-*/Build/Products/Debug/EdgeLauncher.app` (Xcode 디버그 빌드)

### Bundle ID 변경 후 권한이 끊긴 증상

macOS 의 접근성/입력 모니터링 권한은 Bundle ID 단위로 부여됩니다. Bundle ID 가 바뀌면 (예: `com.jongyoungpark.edgelauncher.EdgeLauncher` → `com.jyp.EdgeLauncher`) 새 Bundle ID 는 별개 앱으로 인식되어 권한이 끊깁니다.

증상:

- Edge 디스플레이 터치 시 커서가 Edge 화면으로 이동하지 않고 다른 모니터에 남아있음.
- 합성 클릭이 엉뚱한 위치에서 발생하거나 아예 동작 안 함.

진단: `/tmp/edgelauncher-hid.log` 의 앱 시작 직후 네 줄 확인.

| 값 | 정상 |
|---|---|
| `IOHIDRequestAccess(listen)` | `true` |
| `IOHIDRequestAccess(postEvent)` | `true` |
| `AXIsProcessTrusted` | `true` |
| `manager open(seize) result` | `success` |

하나라도 `false` 또는 `notPermitted` 면 위 절차로 권한 재부여.

### TCC 캐시 리셋 (권한 목록에 안 보이거나 토글이 잠긴 경우)

```bash
tccutil reset Accessibility com.jyp.EdgeLauncher
tccutil reset ListenEvent com.jyp.EdgeLauncher
tccutil reset PostEvent com.jyp.EdgeLauncher
```

리셋 후 EdgeLauncher 를 재시작하면 권한 요청 다이얼로그가 다시 표시됩니다.

## 마이크 권한 (회의록 모듈)

회의록 모듈 진입 시 마이크 권한 배너가 자동으로 나타납니다. 배너의 "권한 요청" 또는 "시스템 설정 열기" 버튼을 사용하세요.

권한 다이얼로그가 아예 뜨지 않는 경우 (TCC DB 캐시 문제):

```bash
tccutil reset Microphone com.jyp.EdgeLauncher
```

실행 후 EdgeLauncher 를 재시작하면 권한 요청 다이얼로그가 다시 표시됩니다.

## 삭제

```bash
rm -rf ~/Applications/EdgeLauncher.app
defaults delete com.jyp.EdgeLauncher 2>/dev/null
```
