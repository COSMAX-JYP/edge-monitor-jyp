import XCTest
@testable import EdgeLauncher

@MainActor
final class EdgeCursorGuardTests: XCTestCase {
    func test_cursorTargetPoint_usesScreenCenter() {
        let frame = CGRect(x: 100, y: 50, width: 2560, height: 720)

        XCTAssertEqual(EdgeCursorGuard.cursorTargetPoint(in: frame), CGPoint(x: 1380, y: 410))
    }

    func test_touchSafeFrame_insetsEdges() {
        let frame = CGRect(x: 0, y: 0, width: 2560, height: 720)
        let safeFrame = EdgeCursorGuard.touchSafeFrame(for: frame)

        XCTAssertTrue(safeFrame.contains(CGPoint(x: 1280, y: 360)))
        XCTAssertFalse(safeFrame.contains(CGPoint(x: 1, y: 360)))
    }

    func test_quartzPoint_flipsYFromAppKitCoordinates() {
        let point = EdgeCursorGuard.quartzPoint(fromAppKitPoint: CGPoint(x: 120, y: 200), mainScreenHeight: 900)

        XCTAssertEqual(point, CGPoint(x: 120, y: 700))
    }

    func test_mapToEdge_returnsCenterWhenEdgeFrameIsDegenerate() {
        let edge = CGRect(x: 0, y: 0, width: 0, height: 0)
        let mapped = EdgeCursorGuard.mapToEdge(CGPoint(x: 500, y: 500), edgeFrame: edge)

        XCTAssertEqual(mapped, CGPoint(x: edge.midX, y: edge.midY))
    }

    func test_mapToEdge_clampsValuesIntoEdgeFrame() {
        let edge = CGRect(x: 1000, y: 200, width: 2560, height: 720)
        let mapped = EdgeCursorGuard.mapToEdge(CGPoint(x: -50_000, y: -50_000), edgeFrame: edge)

        XCTAssertGreaterThanOrEqual(mapped.x, edge.minX)
        XCTAssertLessThanOrEqual(mapped.x, edge.maxX)
        XCTAssertGreaterThanOrEqual(mapped.y, edge.minY)
        XCTAssertLessThanOrEqual(mapped.y, edge.maxY)
    }

    func test_suppressLocalSync_tracksActiveWindow() {
        EdgeCursorGuard.suppressLocalSync(for: 1)

        XCTAssertTrue(EdgeCursorGuard.isLocalSyncSuppressed())
        XCTAssertFalse(EdgeCursorGuard.isLocalSyncSuppressed(now: Date().addingTimeInterval(2)))
    }
}
