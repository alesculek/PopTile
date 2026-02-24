@testable import PopTileCore
import XCTest

final class GeometryTests: XCTestCase {

    // MARK: - Cardinal point helpers

    func testCardinalPoints() {
        let r = Rect(x: 100, y: 200, width: 400, height: 300)
        XCTAssertEqual(north(r).0, 300) // xcenter
        XCTAssertEqual(north(r).1, 200) // y
        XCTAssertEqual(south(r).0, 300) // xcenter
        XCTAssertEqual(south(r).1, 500) // y + height
        XCTAssertEqual(west(r).0, 100)  // x
        XCTAssertEqual(west(r).1, 350)  // ycenter
        XCTAssertEqual(east(r).0, 500)  // x + width
        XCTAssertEqual(east(r).1, 350)  // ycenter
        XCTAssertEqual(center(r).0, 300)
        XCTAssertEqual(center(r).1, 350)
    }

    // MARK: - Distance

    func testDistanceSamePoint() {
        XCTAssertEqual(distance((0, 0), (0, 0)), 0.0)
    }

    func testDistanceKnown() {
        // 3-4-5 triangle
        XCTAssertEqual(distance((0, 0), (3, 4)), 5.0)
    }

    func testDistanceNegative() {
        XCTAssertEqual(distance((5, 5), (2, 1)), 5.0)
    }

    // MARK: - nearestSide

    func testNearestSideLeft() {
        let rect = Rect(x: 100, y: 100, width: 400, height: 300)
        // Cursor near the left edge
        let (_, side) = nearestSide(origin: (105, 250), rect: rect)
        XCTAssertEqual(side, .left)
    }

    func testNearestSideRight() {
        let rect = Rect(x: 100, y: 100, width: 400, height: 300)
        // Cursor near the right edge
        let (_, side) = nearestSide(origin: (495, 250), rect: rect)
        XCTAssertEqual(side, .right)
    }

    func testNearestSideTop() {
        let rect = Rect(x: 100, y: 100, width: 400, height: 300)
        // Cursor near the top edge
        let (_, side) = nearestSide(origin: (300, 105), rect: rect)
        XCTAssertEqual(side, .top)
    }

    func testNearestSideBottom() {
        let rect = Rect(x: 100, y: 100, width: 400, height: 300)
        // Cursor near the bottom edge
        let (_, side) = nearestSide(origin: (300, 395), rect: rect)
        XCTAssertEqual(side, .bottom)
    }

    func testNearestSideCenterWithStacking() {
        let rect = Rect(x: 100, y: 100, width: 400, height: 300)
        // Cursor at exact center
        let c = center(rect)
        let (_, side) = nearestSide(origin: c, rect: rect, stackingWithMouse: true)
        XCTAssertEqual(side, .center)
    }

    func testNearestSideCenterWithoutStacking() {
        let rect = Rect(x: 100, y: 100, width: 400, height: 300)
        // Even at center, without stackingWithMouse, should pick a cardinal side
        let c = center(rect)
        let (_, side) = nearestSide(origin: c, rect: rect, stackingWithMouse: false)
        XCTAssertNotEqual(side, .center)
    }

    // MARK: - shortestSide

    func testShortestSide() {
        let rect = Rect(x: 0, y: 0, width: 200, height: 100)
        // Point near the left edge
        let d = shortestSide(origin: (5, 50), rect: rect)
        // West point is (0, 50), distance from (5, 50) = 5
        XCTAssertEqual(d, 5.0)
    }

    // MARK: - calculateMovement

    func testMovementNone() {
        let r = Rect(x: 0, y: 0, width: 100, height: 100)
        let m = calculateMovement(from: r, change: r)
        XCTAssertEqual(m, .none)
    }

    func testMovementGrowRight() {
        let from = Rect(x: 0, y: 0, width: 100, height: 100)
        let to   = Rect(x: 0, y: 0, width: 150, height: 100)
        let m = calculateMovement(from: from, change: to)
        XCTAssertTrue(m.contains(.grow))
        XCTAssertTrue(m.contains(.right))
    }

    func testMovementShrinkLeft() {
        let from = Rect(x: 0, y: 0, width: 100, height: 100)
        let to   = Rect(x: 0, y: 0, width: 80, height: 100)
        let m = calculateMovement(from: from, change: to)
        XCTAssertTrue(m.contains(.shrink))
        XCTAssertTrue(m.contains(.left))
    }

    func testMovementGrowDown() {
        let from = Rect(x: 0, y: 0, width: 100, height: 100)
        let to   = Rect(x: 0, y: 0, width: 100, height: 150)
        let m = calculateMovement(from: from, change: to)
        XCTAssertTrue(m.contains(.grow))
        XCTAssertTrue(m.contains(.down))
    }

    func testMovementMoved() {
        let from = Rect(x: 0, y: 0, width: 100, height: 100)
        let to   = Rect(x: 50, y: 50, width: 100, height: 100)
        let m = calculateMovement(from: from, change: to)
        XCTAssertEqual(m, .moved)
    }

    // MARK: - roundIncrement

    func testRoundIncrement() {
        XCTAssertEqual(roundIncrement(100, 32), 96)   // 100/32 = 3.125 → 3 * 32 = 96
        XCTAssertEqual(roundIncrement(112, 32), 128)   // 112/32 = 3.5 → 4 * 32 = 128
        XCTAssertEqual(roundIncrement(0, 32), 0)
    }

    func testRoundIncrementZeroIncrement() {
        XCTAssertEqual(roundIncrement(100, 0), 100)
    }
}
