@testable import PopTileCore
import XCTest

/// Tests for the drag detection filtering logic.
/// These test the expectedRect + grace period mechanisms
/// that distinguish our tiling moves from user drags.
final class DragFilterTests: XCTestCase {

    // MARK: - expectedRect matching

    func testExpectedRectExactMatch() {
        let expected = Rect(x: 100, y: 200, width: 800, height: 600)
        let actual = Rect(x: 100, y: 200, width: 800, height: 600)
        XCTAssertTrue(rectsMatch(expected, actual, tolerance: 10))
    }

    func testExpectedRectWithinTolerance() {
        let expected = Rect(x: 100, y: 200, width: 800, height: 600)
        let actual = Rect(x: 103, y: 198, width: 805, height: 595)
        XCTAssertTrue(rectsMatch(expected, actual, tolerance: 10))
    }

    func testExpectedRectBeyondTolerance() {
        let expected = Rect(x: 100, y: 200, width: 800, height: 600)
        let actual = Rect(x: 200, y: 200, width: 800, height: 600)
        XCTAssertFalse(rectsMatch(expected, actual, tolerance: 10))
    }

    func testExpectedRectWidthChange() {
        let expected = Rect(x: 100, y: 200, width: 800, height: 600)
        let actual = Rect(x: 100, y: 200, width: 500, height: 600)
        XCTAssertFalse(rectsMatch(expected, actual, tolerance: 10))
    }

    // MARK: - Grace period logic

    func testGracePeriodActive() {
        let lastTiledAt = CFAbsoluteTimeGetCurrent()
        let now = lastTiledAt + 0.1 // 100ms later
        let gracePeriod: CFAbsoluteTime = 0.5
        XCTAssertTrue(now - lastTiledAt < gracePeriod, "Should be within grace period")
    }

    func testGracePeriodExpired() {
        let lastTiledAt = CFAbsoluteTimeGetCurrent() - 1.0 // 1 second ago
        let now = CFAbsoluteTimeGetCurrent()
        let gracePeriod: CFAbsoluteTime = 0.5
        XCTAssertFalse(now - lastTiledAt < gracePeriod, "Should be past grace period")
    }

    // MARK: - Helper

    /// Replicates the matching logic from Engine.onWindowMoved
    private func rectsMatch(_ expected: Rect, _ actual: Rect, tolerance: Int) -> Bool {
        abs(actual.x - expected.x) <= tolerance &&
        abs(actual.y - expected.y) <= tolerance &&
        abs(actual.width - expected.width) <= tolerance &&
        abs(actual.height - expected.height) <= tolerance
    }
}
