# Xeneon Edge Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corsair Xeneon Edge(2560x720, 32:9, 멀티터치)를 위한 macOS 네이티브 런처 앱의 MVP를 구현한다. 좌측 사이드바에서 탭을 전환하여 YouTube, YouTube Music을 풀폭으로 사용할 수 있다.

**Architecture:** SwiftUI 기반 macOS 14+ 앱. `EdgeModule` 프로토콜과 `ModuleRegistry`로 탭을 모듈화하여 사이드바에 자동 등록. YouTube/YouTube Music은 `WKWebView`로 임베드하며 쿠키 영속화로 로그인을 유지. `NSScreen` 감시로 Xeneon Edge 디스플레이를 자동 감지하고 윈도우를 이동.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit interop, WKWebView, MediaPlayer (Now Playing), XCTest, Xcode 15+, macOS 14 Sonoma+

**Spec:** `docs/superpowers/specs/2026-05-15-xeneon-edge-launcher-design.md`

---

## File Structure

```
EdgeLauncher/
├── EdgeLauncher.xcodeproj/
├── EdgeLauncher/
│   ├── App/
│   │   ├── EdgeLauncherApp.swift            # @main, Scene 정의
│   │   └── AppEnvironment.swift             # ObservableObject 묶음
│   ├── Core/
│   │   ├── Module/
│   │   │   ├── EdgeModule.swift             # 모듈 프로토콜
│   │   │   └── ModuleRegistry.swift         # 모듈 등록/조회
│   │   ├── Display/
│   │   │   └── XeneonDisplayService.swift   # 32:9 디스플레이 감지
│   │   └── Window/
│   │       └── EdgeWindowController.swift   # 윈도우 이동/풀스크린
│   ├── UI/
│   │   ├── RootView.swift                   # NavigationSplitView
│   │   ├── Sidebar.swift                    # 좌측 사이드바
│   │   ├── TabRouter.swift                  # 활성 탭 상태
│   │   └── Components/
│   │       └── TouchableTabButton.swift     # 큰 터치 타겟 버튼
│   ├── Modules/
│   │   ├── YouTube/
│   │   │   ├── YouTubeModule.swift
│   │   │   ├── YouTubeView.swift
│   │   │   └── YouTubeWebView.swift         # NSViewRepresentable + WKWebView
│   │   └── YouTubeMusic/
│   │       ├── YouTubeMusicModule.swift
│   │       ├── YouTubeMusicView.swift
│   │       └── YouTubeMusicWebView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
└── EdgeLauncherTests/
    ├── ModuleRegistryTests.swift
    ├── XeneonDisplayServiceTests.swift
    ├── TabRouterTests.swift
    └── YouTubeModuleTests.swift
```

---

## Task 1: Xcode 프로젝트 셋업

**Files:**
- Create: `EdgeLauncher.xcodeproj` (Xcode GUI에서 생성)
- Create: `EdgeLauncher/Resources/Info.plist`

- [ ] **Step 1: Xcode에서 새 프로젝트 생성**

Xcode > File > New > Project > macOS > App
- Product Name: `EdgeLauncher`
- Team: 개인 Apple ID
- Organization Identifier: `com.<your-name>.edgelauncher`
- Interface: SwiftUI
- Language: Swift
- Storage: None
- Include Tests: 체크
- 저장 위치: `/Users/jongyoungpark/claude/jyp/monitor`

- [ ] **Step 2: Deployment Target을 macOS 14.0으로 설정**

프로젝트 설정 > Targets > EdgeLauncher > General > Minimum Deployments > macOS = 14.0

- [ ] **Step 3: Info.plist에 디스플레이 변경 권한 키 추가**

Info.plist에 추가:
```xml
<key>NSAppleEventsUsageDescription</key>
<string>윈도우를 Xeneon Edge 디스플레이로 이동하기 위해 사용합니다.</string>
```

- [ ] **Step 4: 빌드해서 기본 윈도우가 뜨는지 확인**

Run: Cmd+R
Expected: "Hello, World!" 윈도우 표시

- [ ] **Step 5: Commit**

```bash
cd /Users/jongyoungpark/claude/jyp/monitor
git init
git add .
git commit -m "chore: initial Xcode project for EdgeLauncher"
```

---

## Task 2: EdgeModule 프로토콜 정의

**Files:**
- Create: `EdgeLauncher/Core/Module/EdgeModule.swift`
- Test: `EdgeLauncherTests/EdgeModuleTests.swift`

- [ ] **Step 1: 테스트 작성**

`EdgeLauncherTests/EdgeModuleTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import EdgeLauncher

final class EdgeModuleTests: XCTestCase {
    func test_module_has_required_metadata() {
        let mod = StubModule(id: "stub", title: "Stub", iconName: "circle")
        XCTAssertEqual(mod.id, "stub")
        XCTAssertEqual(mod.title, "Stub")
        XCTAssertEqual(mod.iconName, "circle")
    }
}

struct StubModule: EdgeModule {
    let id: String
    let title: String
    let iconName: String
    var supportsFullscreen: Bool { false }
    @ViewBuilder var view: some View { Text("stub") }
}
```

- [ ] **Step 2: 실패 확인**

Run: Cmd+U
Expected: 컴파일 에러 "Cannot find 'EdgeModule' in scope"

- [ ] **Step 3: 최소 구현**

`EdgeLauncher/Core/Module/EdgeModule.swift`:
```swift
import SwiftUI

protocol EdgeModule {
    associatedtype Body: View
    var id: String { get }
    var title: String { get }
    var iconName: String { get }     // SF Symbol 이름
    var supportsFullscreen: Bool { get }
    @ViewBuilder var view: Body { get }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: Cmd+U
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EdgeLauncher/Core/Module/EdgeModule.swift EdgeLauncherTests/EdgeModuleTests.swift
git commit -m "feat: add EdgeModule protocol"
```

---

## Task 3: ModuleRegistry 구현

**Files:**
- Create: `EdgeLauncher/Core/Module/ModuleRegistry.swift`
- Test: `EdgeLauncherTests/ModuleRegistryTests.swift`

- [ ] **Step 1: 테스트 작성**

`EdgeLauncherTests/ModuleRegistryTests.swift`:
```swift
import XCTest
@testable import EdgeLauncher

final class ModuleRegistryTests: XCTestCase {
    func test_register_and_lookup() {
        let reg = ModuleRegistry()
        let stub = AnyEdgeModule(StubModule(id: "stub", title: "Stub", iconName: "circle"))
        reg.register(stub)
        XCTAssertEqual(reg.modules.count, 1)
        XCTAssertEqual(reg.module(id: "stub")?.title, "Stub")
    }

    func test_duplicate_id_replaces_previous() {
        let reg = ModuleRegistry()
        reg.register(AnyEdgeModule(StubModule(id: "stub", title: "A", iconName: "circle")))
        reg.register(AnyEdgeModule(StubModule(id: "stub", title: "B", iconName: "circle")))
        XCTAssertEqual(reg.modules.count, 1)
        XCTAssertEqual(reg.module(id: "stub")?.title, "B")
    }

    func test_modules_preserve_registration_order() {
        let reg = ModuleRegistry()
        reg.register(AnyEdgeModule(StubModule(id: "a", title: "A", iconName: "circle")))
        reg.register(AnyEdgeModule(StubModule(id: "b", title: "B", iconName: "circle")))
        XCTAssertEqual(reg.modules.map(\.id), ["a", "b"])
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: Cmd+U
Expected: "Cannot find 'ModuleRegistry'"

- [ ] **Step 3: 구현**

`EdgeLauncher/Core/Module/ModuleRegistry.swift`:
```swift
import Combine
import SwiftUI

struct AnyEdgeModule: Identifiable {
    let id: String
    let title: String
    let iconName: String
    let supportsFullscreen: Bool
    let viewBuilder: () -> AnyView

    init<M: EdgeModule>(_ module: M) {
        self.id = module.id
        self.title = module.title
        self.iconName = module.iconName
        self.supportsFullscreen = module.supportsFullscreen
        self.viewBuilder = { AnyView(module.view) }
    }
}

final class ModuleRegistry: ObservableObject {
    @Published private(set) var modules: [AnyEdgeModule] = []

    func register(_ module: AnyEdgeModule) {
        if let idx = modules.firstIndex(where: { $0.id == module.id }) {
            modules[idx] = module
        } else {
            modules.append(module)
        }
    }

    func module(id: String) -> AnyEdgeModule? {
        modules.first { $0.id == id }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: Cmd+U
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EdgeLauncher/Core/Module/ModuleRegistry.swift EdgeLauncherTests/ModuleRegistryTests.swift
git commit -m "feat: add ModuleRegistry with type-erased AnyEdgeModule"
```

---

## Task 4: TabRouter 상태 관리

**Files:**
- Create: `EdgeLauncher/UI/TabRouter.swift`
- Test: `EdgeLauncherTests/TabRouterTests.swift`

- [ ] **Step 1: 테스트 작성**

`EdgeLauncherTests/TabRouterTests.swift`:
```swift
import XCTest
@testable import EdgeLauncher

final class TabRouterTests: XCTestCase {
    func test_initial_active_id_is_nil() {
        let router = TabRouter()
        XCTAssertNil(router.activeID)
    }

    func test_activate_sets_id() {
        let router = TabRouter()
        router.activate("youtube")
        XCTAssertEqual(router.activeID, "youtube")
    }

    func test_persisted_active_id_loads_from_defaults() {
        let suite = UserDefaults(suiteName: #function)!
        suite.set("youtube-music", forKey: "app.activeTab")
        let router = TabRouter(defaults: suite)
        XCTAssertEqual(router.activeID, "youtube-music")
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: Cmd+U
Expected: "Cannot find 'TabRouter'"

- [ ] **Step 3: 구현**

`EdgeLauncher/UI/TabRouter.swift`:
```swift
import Foundation
import Combine

final class TabRouter: ObservableObject {
    @Published var activeID: String? {
        didSet { defaults.set(activeID, forKey: Self.key) }
    }

    private let defaults: UserDefaults
    private static let key = "app.activeTab"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.activeID = defaults.string(forKey: Self.key)
    }

    func activate(_ id: String) {
        activeID = id
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: Cmd+U
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EdgeLauncher/UI/TabRouter.swift EdgeLauncherTests/TabRouterTests.swift
git commit -m "feat: add TabRouter with UserDefaults persistence"
```

---

## Task 5: TouchableTabButton 컴포넌트

**Files:**
- Create: `EdgeLauncher/UI/Components/TouchableTabButton.swift`

- [ ] **Step 1: 구현**

테스트는 SwiftUI 뷰 렌더링이라 단위 테스트 대신 프리뷰로 검증.

`EdgeLauncher/UI/Components/TouchableTabButton.swift`:
```swift
import SwiftUI

struct TouchableTabButton: View {
    let iconName: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 28, weight: .medium))
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isActive ? Color.accentColor.opacity(0.25) : Color.clear)
                    )
                Text(title)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .frame(width: 84, height: 84)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#Preview {
    VStack {
        TouchableTabButton(iconName: "play.rectangle.fill", title: "YouTube", isActive: true) {}
        TouchableTabButton(iconName: "music.note", title: "Music", isActive: false) {}
    }
    .padding()
    .frame(width: 110)
}
```

- [ ] **Step 2: 프리뷰로 시각 확인**

Xcode > Editor > Canvas
Expected: 활성/비활성 두 버튼이 정상 렌더링

- [ ] **Step 3: Commit**

```bash
git add EdgeLauncher/UI/Components/TouchableTabButton.swift
git commit -m "feat: add TouchableTabButton with 56x56 hit target"
```

---

## Task 6: Sidebar UI

**Files:**
- Create: `EdgeLauncher/UI/Sidebar.swift`

- [ ] **Step 1: 구현**

`EdgeLauncher/UI/Sidebar.swift`:
```swift
import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: 24))
                .padding(.vertical, 16)

            Divider()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(registry.modules) { module in
                        TouchableTabButton(
                            iconName: module.iconName,
                            title: module.title,
                            isActive: router.activeID == module.id
                        ) {
                            router.activate(module.id)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()

            Divider()

            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 22))
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .frame(width: 110)
        .background(.regularMaterial)
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add EdgeLauncher/UI/Sidebar.swift
git commit -m "feat: add left Sidebar with module list"
```

---

## Task 7: RootView (NavigationSplitView)

**Files:**
- Create: `EdgeLauncher/UI/RootView.swift`

- [ ] **Step 1: 구현**

`EdgeLauncher/UI/RootView.swift`:
```swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var registry: ModuleRegistry
    @EnvironmentObject var router: TabRouter

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1280, minHeight: 480)
    }

    @ViewBuilder
    private var content: some View {
        if let id = router.activeID, let module = registry.module(id: id) {
            module.viewBuilder()
                .id(module.id)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.split.2x1")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("좌측에서 탭을 선택하세요")
                .foregroundStyle(.secondary)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add EdgeLauncher/UI/RootView.swift
git commit -m "feat: add RootView with sidebar + content split"
```

---

## Task 8: AppEnvironment과 App entry point

**Files:**
- Modify: `EdgeLauncher/App/EdgeLauncherApp.swift`
- Create: `EdgeLauncher/App/AppEnvironment.swift`

- [ ] **Step 1: AppEnvironment 생성**

`EdgeLauncher/App/AppEnvironment.swift`:
```swift
import Foundation

final class AppEnvironment: ObservableObject {
    let registry: ModuleRegistry
    let router: TabRouter

    init() {
        self.registry = ModuleRegistry()
        self.router = TabRouter()
    }
}
```

- [ ] **Step 2: App 진입점 수정**

`EdgeLauncher/App/EdgeLauncherApp.swift` 전체 교체:
```swift
import SwiftUI

@main
struct EdgeLauncherApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup("Edge Launcher") {
            RootView()
                .environmentObject(env.registry)
                .environmentObject(env.router)
                .frame(minWidth: 1280, idealWidth: 2560, minHeight: 480, idealHeight: 720)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(env)
        }
    }
}
```

- [ ] **Step 3: SettingsView 스텁 생성**

`EdgeLauncher/Settings/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Text("설정은 다음 단계에서 구현합니다.")
        }
        .padding(24)
        .frame(width: 480, height: 240)
    }
}
```

- [ ] **Step 4: 빌드 확인**

Run: Cmd+R
Expected: 사이드바와 placeholder만 보이는 윈도우 표시 (모듈 미등록)

- [ ] **Step 5: Commit**

```bash
git add EdgeLauncher/App EdgeLauncher/Settings/SettingsView.swift
git commit -m "feat: wire AppEnvironment, RootView, Settings stub"
```

---

## Task 9: YouTube WebView 래퍼

**Files:**
- Create: `EdgeLauncher/Modules/YouTube/YouTubeWebView.swift`

- [ ] **Step 1: 구현**

`EdgeLauncher/Modules/YouTube/YouTubeWebView.swift`:
```swift
import SwiftUI
import WebKit

struct YouTubeWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()                       // 쿠키 영속
        config.mediaTypesRequiringUserActionForPlayback = []       // 자동재생 허용
        config.allowsAirPlayForMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add EdgeLauncher/Modules/YouTube/YouTubeWebView.swift
git commit -m "feat: add YouTubeWebView wrapping WKWebView with autoplay"
```

---

## Task 10: YouTube Module과 View

**Files:**
- Create: `EdgeLauncher/Modules/YouTube/YouTubeView.swift`
- Create: `EdgeLauncher/Modules/YouTube/YouTubeModule.swift`
- Modify: `EdgeLauncher/App/AppEnvironment.swift`

- [ ] **Step 1: YouTubeView 작성**

`EdgeLauncher/Modules/YouTube/YouTubeView.swift`:
```swift
import SwiftUI

struct YouTubeView: View {
    var body: some View {
        YouTubeWebView(url: URL(string: "https://www.youtube.com")!)
            .ignoresSafeArea()
    }
}
```

- [ ] **Step 2: YouTubeModule 작성**

`EdgeLauncher/Modules/YouTube/YouTubeModule.swift`:
```swift
import SwiftUI

struct YouTubeModule: EdgeModule {
    let id = "youtube"
    let title = "YouTube"
    let iconName = "play.rectangle.fill"
    let supportsFullscreen = true

    var view: some View { YouTubeView() }
}
```

- [ ] **Step 3: AppEnvironment에 등록**

`EdgeLauncher/App/AppEnvironment.swift` 수정:
```swift
import Foundation

final class AppEnvironment: ObservableObject {
    let registry: ModuleRegistry
    let router: TabRouter

    init() {
        let registry = ModuleRegistry()
        registry.register(AnyEdgeModule(YouTubeModule()))
        self.registry = registry

        let router = TabRouter()
        if router.activeID == nil { router.activate("youtube") }
        self.router = router
    }
}
```

- [ ] **Step 4: 실행 확인**

Run: Cmd+R
Expected: 사이드바에 YouTube 탭, 우측에 youtube.com 로딩

- [ ] **Step 5: Commit**

```bash
git add EdgeLauncher/Modules/YouTube EdgeLauncher/App/AppEnvironment.swift
git commit -m "feat: register YouTube module as first tab"
```

---

## Task 11: YouTube 터치 제스처 (JS 인젝션)

**Files:**
- Modify: `EdgeLauncher/Modules/YouTube/YouTubeWebView.swift`

- [ ] **Step 1: 더블탭 좌/우 10초 점프 스크립트 작성**

스크립트 파일 대신 인라인 문자열 사용. `YouTubeWebView.swift`의 `makeNSView` 내부에서 `WKUserScript` 주입:

```swift
let script = """
(function() {
  let lastTap = 0; let lastX = 0;
  document.addEventListener('touchend', function(e) {
    const now = Date.now();
    const x = e.changedTouches[0].clientX;
    if (now - lastTap < 350 && Math.abs(x - lastX) < 60) {
      const video = document.querySelector('video');
      if (video) {
        const w = window.innerWidth;
        if (x < w / 2) video.currentTime = Math.max(0, video.currentTime - 10);
        else video.currentTime = Math.min(video.duration, video.currentTime + 10);
      }
      lastTap = 0;
    } else {
      lastTap = now; lastX = x;
    }
  }, { passive: true });
})();
"""

let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
config.userContentController.addUserScript(userScript)
```

`makeNSView` 본문에 `config.userContentController.addUserScript(...)` 호출 추가. `WKWebViewConfiguration` 선언 직후 추가.

- [ ] **Step 2: 실행해서 터치(또는 트랙패드 더블탭)로 점프 확인**

Run: Cmd+R
영상 재생 중 우측 더블탭으로 10초 앞, 좌측 더블탭으로 10초 뒤로 이동되는지 확인.

- [ ] **Step 3: Commit**

```bash
git add EdgeLauncher/Modules/YouTube/YouTubeWebView.swift
git commit -m "feat: inject double-tap seek script in YouTube webview"
```

---

## Task 12: YouTube Music WebView 래퍼

**Files:**
- Create: `EdgeLauncher/Modules/YouTubeMusic/YouTubeMusicWebView.swift`

- [ ] **Step 1: 구현**

`EdgeLauncher/Modules/YouTubeMusic/YouTubeMusicWebView.swift`:
```swift
import SwiftUI
import WebKit

struct YouTubeMusicWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add EdgeLauncher/Modules/YouTubeMusic/YouTubeMusicWebView.swift
git commit -m "feat: add YouTubeMusicWebView wrapper"
```

---

## Task 13: YouTube Music Module과 View

**Files:**
- Create: `EdgeLauncher/Modules/YouTubeMusic/YouTubeMusicView.swift`
- Create: `EdgeLauncher/Modules/YouTubeMusic/YouTubeMusicModule.swift`
- Modify: `EdgeLauncher/App/AppEnvironment.swift`

- [ ] **Step 1: YouTubeMusicView 작성**

`EdgeLauncher/Modules/YouTubeMusic/YouTubeMusicView.swift`:
```swift
import SwiftUI

struct YouTubeMusicView: View {
    var body: some View {
        YouTubeMusicWebView(url: URL(string: "https://music.youtube.com")!)
            .ignoresSafeArea()
    }
}
```

- [ ] **Step 2: YouTubeMusicModule 작성**

`EdgeLauncher/Modules/YouTubeMusic/YouTubeMusicModule.swift`:
```swift
import SwiftUI

struct YouTubeMusicModule: EdgeModule {
    let id = "youtube-music"
    let title = "Music"
    let iconName = "music.note"
    let supportsFullscreen = true

    var view: some View { YouTubeMusicView() }
}
```

- [ ] **Step 3: AppEnvironment에 등록**

`EdgeLauncher/App/AppEnvironment.swift`의 `init()`에서 `registry.register(AnyEdgeModule(YouTubeModule()))` 다음 줄에 추가:

```swift
registry.register(AnyEdgeModule(YouTubeMusicModule()))
```

- [ ] **Step 4: 실행 확인**

Run: Cmd+R
Expected: 사이드바 두 탭, Music 탭 클릭 시 music.youtube.com 로딩

- [ ] **Step 5: Commit**

```bash
git add EdgeLauncher/Modules/YouTubeMusic EdgeLauncher/App/AppEnvironment.swift
git commit -m "feat: register YouTube Music module as second tab"
```

---

## Task 14: XeneonDisplayService (디스플레이 감지)

**Files:**
- Create: `EdgeLauncher/Core/Display/XeneonDisplayService.swift`
- Test: `EdgeLauncherTests/XeneonDisplayServiceTests.swift`

- [ ] **Step 1: 테스트 작성**

`EdgeLauncherTests/XeneonDisplayServiceTests.swift`:
```swift
import XCTest
import AppKit
@testable import EdgeLauncher

final class XeneonDisplayServiceTests: XCTestCase {
    func test_matches_2560x720_resolution() {
        XCTAssertTrue(XeneonDisplayService.isEdgeDisplay(width: 2560, height: 720))
    }

    func test_does_not_match_other_resolutions() {
        XCTAssertFalse(XeneonDisplayService.isEdgeDisplay(width: 2560, height: 1440))
        XCTAssertFalse(XeneonDisplayService.isEdgeDisplay(width: 1920, height: 1080))
    }

    func test_matches_with_minor_dpi_rounding() {
        XCTAssertTrue(XeneonDisplayService.isEdgeDisplay(width: 2559, height: 720))
        XCTAssertTrue(XeneonDisplayService.isEdgeDisplay(width: 2560, height: 721))
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: Cmd+U
Expected: "Cannot find 'XeneonDisplayService'"

- [ ] **Step 3: 구현**

`EdgeLauncher/Core/Display/XeneonDisplayService.swift`:
```swift
import AppKit
import Combine

final class XeneonDisplayService: ObservableObject {
    @Published private(set) var edgeScreen: NSScreen?

    private var cancellable: AnyCancellable?

    init() {
        refresh()
        cancellable = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        edgeScreen = NSScreen.screens.first { screen in
            let size = screen.frame.size
            return Self.isEdgeDisplay(width: Int(size.width), height: Int(size.height))
        }
    }

    static func isEdgeDisplay(width: Int, height: Int) -> Bool {
        let widthOK = abs(width - 2560) <= 4
        let heightOK = abs(height - 720) <= 4
        return widthOK && heightOK
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: Cmd+U
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EdgeLauncher/Core/Display EdgeLauncherTests/XeneonDisplayServiceTests.swift
git commit -m "feat: add XeneonDisplayService detecting 2560x720 screen"
```

---

## Task 15: EdgeWindowController (이동 및 풀스크린)

**Files:**
- Create: `EdgeLauncher/Core/Window/EdgeWindowController.swift`
- Modify: `EdgeLauncher/App/AppEnvironment.swift`
- Modify: `EdgeLauncher/App/EdgeLauncherApp.swift`

- [ ] **Step 1: 구현**

`EdgeLauncher/Core/Window/EdgeWindowController.swift`:
```swift
import AppKit

@MainActor
final class EdgeWindowController {
    private let displayService: XeneonDisplayService

    init(displayService: XeneonDisplayService) {
        self.displayService = displayService
    }

    func moveMainWindowToEdge() {
        guard let window = NSApp.mainWindow ?? NSApp.windows.first else { return }
        guard let screen = displayService.edgeScreen else {
            NSSound.beep()
            return
        }
        let frame = screen.visibleFrame
        window.setFrame(frame, display: true, animate: true)
    }

    func toggleFullScreen() {
        guard let window = NSApp.mainWindow ?? NSApp.windows.first else { return }
        window.toggleFullScreen(nil)
    }
}
```

- [ ] **Step 2: AppEnvironment에 추가**

`EdgeLauncher/App/AppEnvironment.swift`의 클래스 본문에 추가:
```swift
let displayService: XeneonDisplayService
let windowController: EdgeWindowController
```

`init()` 내부 (`router` 초기화 이후)에 추가:
```swift
self.displayService = XeneonDisplayService()
self.windowController = EdgeWindowController(displayService: self.displayService)
```

- [ ] **Step 3: Sidebar 하단에 Edge 전환 버튼 추가**

`EdgeLauncher/UI/Sidebar.swift`의 `@EnvironmentObject` 옆에 추가:
```swift
@EnvironmentObject var displayService: XeneonDisplayService
```

설정 버튼 위에 다음 버튼을 추가:
```swift
Button(action: { NotificationCenter.default.post(name: .edgeMoveRequested, object: nil) }) {
    Image(systemName: "rectangle.portrait.and.arrow.right")
        .font(.system(size: 22))
        .frame(width: 56, height: 56)
        .opacity(displayService.edgeScreen == nil ? 0.3 : 1.0)
}
.buttonStyle(.plain)
.disabled(displayService.edgeScreen == nil)
.help("Xeneon Edge로 이동")
```

- [ ] **Step 4: Notification.Name 확장과 핸들러 등록**

`EdgeLauncher/Core/Window/EdgeWindowController.swift` 하단에 추가:
```swift
extension Notification.Name {
    static let edgeMoveRequested = Notification.Name("edge.move.requested")
}
```

`EdgeLauncherApp.swift`의 `WindowGroup` 내부 `RootView()`에 `.environmentObject(env.displayService)` 추가하고, `.onAppear`로 옵저버 부착:
```swift
RootView()
    .environmentObject(env.registry)
    .environmentObject(env.router)
    .environmentObject(env.displayService)
    .onAppear {
        NotificationCenter.default.addObserver(
            forName: .edgeMoveRequested, object: nil, queue: .main
        ) { _ in
            env.windowController.moveMainWindowToEdge()
        }
    }
```

- [ ] **Step 5: 실행 확인**

Run: Cmd+R
Xeneon Edge 연결 상태에 따라 사이드바 하단 버튼이 활성/비활성. 활성 상태에서 클릭 시 윈도우가 Edge 화면으로 이동.

- [ ] **Step 6: Commit**

```bash
git add EdgeLauncher
git commit -m "feat: add EdgeWindowController and sidebar move button"
```

---

## Task 16: 미디어 키와 Now Playing 연동

**Files:**
- Create: `EdgeLauncher/Core/Media/NowPlayingBridge.swift`
- Modify: `EdgeLauncher/Modules/YouTubeMusic/YouTubeMusicWebView.swift`

YouTube Music은 자체적으로 `MediaSession API`를 사용한다. macOS Safari/WebKit이 이를 Now Playing으로 자동 노출해주므로 추가 구현은 최소.

- [ ] **Step 1: WKWebView Configuration에 미디어 세션 활성화 확인**

`YouTubeMusicWebView.swift`에서 `config`에 추가:
```swift
config.preferences.setValue(true, forKey: "mediaSessionEnabled")
```

(주의: 비공개 API 키지만 WebKit에서 동작 확인된 키. 실패 시 무시.)

- [ ] **Step 2: 실행해서 미디어 키 동작 확인**

Run: Cmd+R, YouTube Music 탭에서 곡 재생.
키보드의 재생/일시정지/다음/이전 키로 컨트롤 가능한지 확인.
제어센터 Now Playing에 현재 곡이 표시되는지 확인.

- [ ] **Step 3: 동작하지 않으면 미해결 사항 노트만 남기고 다음 단계 진행**

`EdgeLauncher/Core/Media/NowPlayingBridge.swift` (스텁):
```swift
import Foundation

// MediaSession API 자동 전달이 동작하지 않을 경우 MPRemoteCommandCenter와
// MPNowPlayingInfoCenter를 사용해 JS bridge로 곡 정보를 직접 전달하도록 확장.
// MVP에서는 WebKit 기본 동작에 의존.
enum NowPlayingBridge {
    static let placeholder = "see Task 16 follow-up"
}
```

- [ ] **Step 4: Commit**

```bash
git add EdgeLauncher
git commit -m "feat: enable media session in YouTube Music webview"
```

---

## Task 17: 설정 UI 구현

**Files:**
- Modify: `EdgeLauncher/Settings/SettingsView.swift`

- [ ] **Step 1: 구현**

`EdgeLauncher/Settings/SettingsView.swift` 전체 교체:
```swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("app.autoMoveOnLaunch") private var autoMoveOnLaunch = false
    @AppStorage("app.startInFullScreen") private var startInFullScreen = false

    var body: some View {
        TabView {
            Form {
                Toggle("앱 실행 시 Xeneon Edge로 자동 이동", isOn: $autoMoveOnLaunch)
                Toggle("Edge 이동 시 자동 풀스크린", isOn: $startInFullScreen)
            }
            .padding(24)
            .tabItem { Label("일반", systemImage: "gearshape") }

            Form {
                Text("탭 순서 편집은 다음 릴리스에서 지원합니다.")
            }
            .padding(24)
            .tabItem { Label("탭", systemImage: "rectangle.split.3x1") }
        }
        .frame(width: 520, height: 280)
    }
}
```

- [ ] **Step 2: 자동 이동 옵션을 EdgeLauncherApp에서 처리**

`EdgeLauncherApp.swift`의 `.onAppear`에서 옵저버 등록 직후 추가:
```swift
if UserDefaults.standard.bool(forKey: "app.autoMoveOnLaunch") {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        env.windowController.moveMainWindowToEdge()
        if UserDefaults.standard.bool(forKey: "app.startInFullScreen") {
            env.windowController.toggleFullScreen()
        }
    }
}
```

- [ ] **Step 3: 실행 확인**

Cmd+, 로 설정 열고 토글 변경. 재실행 시 동작 확인.

- [ ] **Step 4: Commit**

```bash
git add EdgeLauncher/Settings EdgeLauncher/App/EdgeLauncherApp.swift
git commit -m "feat: add settings for auto-move and fullscreen"
```

---

## Task 18: YouTube Module 통합 테스트

**Files:**
- Create: `EdgeLauncherTests/YouTubeModuleTests.swift`

- [ ] **Step 1: 테스트 작성**

`EdgeLauncherTests/YouTubeModuleTests.swift`:
```swift
import XCTest
@testable import EdgeLauncher

final class YouTubeModuleTests: XCTestCase {
    func test_metadata() {
        let mod = YouTubeModule()
        XCTAssertEqual(mod.id, "youtube")
        XCTAssertEqual(mod.title, "YouTube")
        XCTAssertEqual(mod.iconName, "play.rectangle.fill")
        XCTAssertTrue(mod.supportsFullscreen)
    }

    func test_music_metadata() {
        let mod = YouTubeMusicModule()
        XCTAssertEqual(mod.id, "youtube-music")
        XCTAssertEqual(mod.title, "Music")
        XCTAssertEqual(mod.iconName, "music.note")
        XCTAssertTrue(mod.supportsFullscreen)
    }

    func test_environment_registers_both_modules() {
        let env = AppEnvironment()
        let ids = env.registry.modules.map(\.id)
        XCTAssertEqual(ids, ["youtube", "youtube-music"])
    }
}
```

- [ ] **Step 2: 테스트 통과 확인**

Run: Cmd+U
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add EdgeLauncherTests/YouTubeModuleTests.swift
git commit -m "test: cover YouTube and YouTubeMusic module metadata"
```

---

## Task 19: 최종 검수 체크리스트

문서로만 진행. 코드 변경 없음.

- [ ] **Step 1: 실기기 검수**

다음 항목을 Xeneon Edge에 연결한 상태에서 확인:
1. 앱 실행 시 사이드바와 YouTube 탭이 보이는가
2. Music 탭 클릭 시 music.youtube.com이 로딩되는가
3. Sidebar의 "Edge로 이동" 버튼이 활성 상태인가
4. 클릭 시 윈도우가 Xeneon Edge로 이동하는가
5. 설정에서 자동 이동을 켜고 재실행 시 자동 이동되는가
6. YouTube 영상에서 더블탭 좌/우 10초 점프가 동작하는가
7. YouTube Music 재생 중 키보드 미디어 키가 동작하는가
8. 제어센터 Now Playing 위젯에 곡 정보가 보이는가
9. 풀스크린 토글이 정상 동작하는가
10. 로그아웃 후 재시작 시 로그인이 유지되는가

- [ ] **Step 2: 발견된 이슈를 follow-up 이슈로 기록**

이슈를 `docs/superpowers/specs/2026-05-15-xeneon-edge-launcher-design.md`의 "14. 미해결 사항" 섹션에 추가.

- [ ] **Step 3: README 작성**

`README.md`:
```markdown
# EdgeLauncher

Corsair Xeneon Edge(2560x720, 32:9)를 위한 macOS 네이티브 런처.

## 요구사항
- macOS 14 Sonoma+
- Xcode 15+

## 빌드
Xcode로 `EdgeLauncher.xcodeproj`를 열고 Cmd+R.

## MVP 모듈
- YouTube
- YouTube Music

## 다음 단계 (Phase 2)
시스템 모니터, 위젯 대시보드, 메신저 사이드 패널, 런처, 앰비언트 모드.
```

- [ ] **Step 4: 최종 Commit**

```bash
git add README.md docs
git commit -m "docs: add README and update spec follow-ups"
```

---

## 완료 기준

- 19개 Task의 모든 step 체크박스가 완료됨
- `Cmd+U`로 전체 단위 테스트가 통과
- 실기기 검수 항목 10개가 모두 통과
- Phase 2 모듈은 별도 plan으로 분리하여 후속 작업
