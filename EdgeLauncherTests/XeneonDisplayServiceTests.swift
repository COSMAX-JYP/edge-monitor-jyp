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
