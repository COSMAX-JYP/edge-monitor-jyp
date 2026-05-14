import XCTest
@testable import EdgeLauncher

@MainActor
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
