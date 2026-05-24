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

    @MainActor
    func test_environment_registers_phase1_and_phase2_modules() {
        let env = AppEnvironment()
        let ids = Set(env.registry.modules.map(\.id))
        XCTAssertEqual(ids, [
            "youtube", "youtube-music",
            "system-monitor", "widgets",
            "messenger", "messenger-2", "messenger-3", "messenger-4", "launcher",
            "browser",
            "outlook-calendar", "notion",
            "timeline", "kanban", "streamdeck", "lock-screen",
            "meeting-recorder"
        ])
    }
}
