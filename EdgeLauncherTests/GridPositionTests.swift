import XCTest
@testable import EdgeLauncher

final class GridPositionTests: XCTestCase {

    func test_gridSize_default_is3x12() {
        XCTAssertEqual(GridSize.default.rows, 3)
        XCTAssertEqual(GridSize.default.cols, 12)
        XCTAssertEqual(GridSize.default.totalSlots, 36)
    }

    func test_gridSize_contains_inRange() {
        let size = GridSize.default
        XCTAssertTrue(size.contains(GridPosition(row: 0, col: 0)))
        XCTAssertTrue(size.contains(GridPosition(row: 2, col: 11)))
    }

    func test_gridSize_contains_outOfRange() {
        let size = GridSize.default
        XCTAssertFalse(size.contains(GridPosition(row: 3, col: 0)))
        XCTAssertFalse(size.contains(GridPosition(row: 0, col: 12)))
        XCTAssertFalse(size.contains(GridPosition(row: -1, col: 0)))
    }

    func test_gridPosition_equality() {
        let a = GridPosition(row: 1, col: 2)
        let b = GridPosition(row: 1, col: 2)
        let c = GridPosition(row: 2, col: 1)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
