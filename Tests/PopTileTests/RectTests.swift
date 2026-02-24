@testable import PopTileCore
import XCTest

final class RectTests: XCTestCase {

    // MARK: - Construction

    func testZero() {
        let r = Rect.zero
        XCTAssertEqual(r.x, 0)
        XCTAssertEqual(r.y, 0)
        XCTAssertEqual(r.width, 0)
        XCTAssertEqual(r.height, 0)
    }

    func testInitFromArray() {
        let r = Rect([10, 20, 300, 400])
        XCTAssertEqual(r.x, 10)
        XCTAssertEqual(r.y, 20)
        XCTAssertEqual(r.width, 300)
        XCTAssertEqual(r.height, 400)
    }

    func testInitFromCGRect() {
        let cg = CGRect(x: 10.7, y: 20.3, width: 300.9, height: 400.1)
        let r = Rect(from: cg)
        XCTAssertEqual(r.x, 10)
        XCTAssertEqual(r.y, 20)
        XCTAssertEqual(r.width, 300)
        XCTAssertEqual(r.height, 400)
    }

    func testInitFromCGRectWithNaN() {
        let cg = CGRect(x: CGFloat.nan, y: CGFloat.infinity, width: 100, height: CGFloat.nan)
        let r = Rect(from: cg)
        XCTAssertEqual(r.x, 0)
        XCTAssertEqual(r.y, 0)
        XCTAssertEqual(r.width, 100)
        XCTAssertEqual(r.height, 0)
    }

    func testCGRectConversion() {
        let r = Rect(x: 10, y: 20, width: 300, height: 400)
        let cg = r.cgRect
        XCTAssertEqual(cg.origin.x, 10)
        XCTAssertEqual(cg.origin.y, 20)
        XCTAssertEqual(cg.size.width, 300)
        XCTAssertEqual(cg.size.height, 400)
    }

    // MARK: - Clone

    func testClone() {
        let r = Rect(x: 1, y: 2, width: 3, height: 4)
        var c = r.clone()
        c.x = 99
        XCTAssertEqual(r.x, 1, "Original should not be modified")
        XCTAssertEqual(c.x, 99)
    }

    // MARK: - Apply / Applied

    func testApply() {
        var r = Rect(x: 10, y: 20, width: 100, height: 200)
        r.apply(Rect(x: 5, y: -10, width: 50, height: -50))
        XCTAssertEqual(r, Rect(x: 15, y: 10, width: 150, height: 150))
    }

    func testApplied() {
        let r = Rect(x: 10, y: 20, width: 100, height: 200)
        let result = r.applied(Rect(x: 5, y: 5, width: 10, height: 10))
        XCTAssertEqual(result, Rect(x: 15, y: 25, width: 110, height: 210))
        XCTAssertEqual(r.x, 10, "Original should not be modified")
    }

    // MARK: - Clamp

    func testClampInsideBounds() {
        var r = Rect(x: 50, y: 50, width: 100, height: 100)
        let bounds = Rect(x: 0, y: 0, width: 500, height: 500)
        r.clamp(bounds)
        XCTAssertEqual(r, Rect(x: 50, y: 50, width: 100, height: 100))
    }

    func testClampOverflowRight() {
        var r = Rect(x: 400, y: 50, width: 200, height: 100)
        let bounds = Rect(x: 0, y: 0, width: 500, height: 500)
        r.clamp(bounds)
        XCTAssertEqual(r.x, 400)
        XCTAssertEqual(r.width, 100, "Width clamped so right edge = 500")
    }

    func testClampOverflowLeft() {
        var r = Rect(x: -50, y: 50, width: 200, height: 100)
        let bounds = Rect(x: 0, y: 0, width: 500, height: 500)
        r.clamp(bounds)
        XCTAssertEqual(r.x, 0, "x clamped to bounds.x")
    }

    // MARK: - Contains

    func testContainsSelf() {
        let r = Rect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertTrue(r.contains(r))
    }

    func testContainsSmaller() {
        let outer = Rect(x: 0, y: 0, width: 100, height: 100)
        let inner = Rect(x: 10, y: 10, width: 50, height: 50)
        XCTAssertTrue(outer.contains(inner))
        XCTAssertFalse(inner.contains(outer))
    }

    func testDoesNotContainPartial() {
        let a = Rect(x: 0, y: 0, width: 100, height: 100)
        let b = Rect(x: 50, y: 50, width: 100, height: 100)
        XCTAssertFalse(a.contains(b))
    }

    // MARK: - Diff

    func testDiff() {
        let a = Rect(x: 10, y: 20, width: 100, height: 200)
        let b = Rect(x: 15, y: 25, width: 110, height: 220)
        let d = a.diff(b)
        XCTAssertEqual(d, Rect(x: 5, y: 5, width: 10, height: 20))
    }

    // MARK: - Intersects

    func testIntersectsOverlap() {
        let a = Rect(x: 0, y: 0, width: 100, height: 100)
        let b = Rect(x: 50, y: 50, width: 100, height: 100)
        XCTAssertTrue(a.intersects(b))
        XCTAssertTrue(b.intersects(a))
    }

    func testIntersectsNoOverlap() {
        let a = Rect(x: 0, y: 0, width: 100, height: 100)
        let b = Rect(x: 200, y: 200, width: 100, height: 100)
        XCTAssertFalse(a.intersects(b))
    }

    func testIntersectsAdjacent() {
        let a = Rect(x: 0, y: 0, width: 100, height: 100)
        let b = Rect(x: 100, y: 0, width: 100, height: 100)
        XCTAssertFalse(a.intersects(b), "Touching edges should not intersect")
    }

    // MARK: - Equatable

    func testEquality() {
        let a = Rect(x: 1, y: 2, width: 3, height: 4)
        let b = Rect(x: 1, y: 2, width: 3, height: 4)
        let c = Rect(x: 1, y: 2, width: 3, height: 5)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
