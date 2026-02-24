@testable import PopTileCore
import XCTest

/// Tests for the resize handling logic in Engine.onWindowResized.
///
/// Key scenarios:
/// 1. expectedRect nil → resize must not be silently ignored
/// 2. expectedRect set → calculateMovement detects edge resizes
/// 3. After onWindowMoved clears expectedRect, resize still works
/// 4. Corner resize (both x & y change + size change) from resize notification
/// 5. Active border should be updated after resize operations
/// 6. Stacked (grouped) windows must ALL be resized together
final class ResizeHandlerTests: XCTestCase {

    // MARK: - Bug: expectedRect nil causes resize to be ignored

    /// When expectedRect is nil and the window is resized, fromRect == newRect
    /// so calculateMovement returns .none → resize silently ignored.
    func testCalculateMovementIdenticalRectsReturnsNone() {
        let rect = Rect(x: 100, y: 50, width: 800, height: 600)
        let movement = calculateMovement(from: rect, change: rect)
        XCTAssertEqual(movement, .none, "Identical rects must return .none")
    }

    /// After onWindowMoved clears expectedRect, the fallback `?? newRect` makes
    /// fromRect equal to newRect. Verify that calculateMovement(same, same) = .none.
    func testNilExpectedRectFallbackProducesNoMovement() {
        let newRect = Rect(x: 100, y: 50, width: 900, height: 600)
        let fromRect = newRect // This is what `?? newRect` gives us
        let movement = calculateMovement(from: fromRect, change: newRect)
        XCTAssertEqual(movement, .none,
                       "When expectedRect is nil and fallback is newRect, movement is always .none — this is the bug")
    }

    // MARK: - Right edge resize detection

    func testRightEdgeGrow() {
        let from = Rect(x: 100, y: 50, width: 800, height: 600)
        let to   = Rect(x: 100, y: 50, width: 900, height: 600)
        let m = calculateMovement(from: from, change: to)
        XCTAssertTrue(m.contains(.grow))
        XCTAssertTrue(m.contains(.right))
        XCTAssertFalse(m.contains(.moved))
    }

    func testRightEdgeShrink() {
        let from = Rect(x: 100, y: 50, width: 800, height: 600)
        let to   = Rect(x: 100, y: 50, width: 700, height: 600)
        let m = calculateMovement(from: from, change: to)
        XCTAssertTrue(m.contains(.shrink))
        XCTAssertTrue(m.contains(.left))
    }

    // MARK: - Bottom edge resize detection

    func testBottomEdgeGrow() {
        let from = Rect(x: 100, y: 50, width: 800, height: 600)
        let to   = Rect(x: 100, y: 50, width: 800, height: 700)
        let m = calculateMovement(from: from, change: to)
        XCTAssertTrue(m.contains(.grow))
        XCTAssertTrue(m.contains(.down))
    }

    func testBottomEdgeShrink() {
        let from = Rect(x: 100, y: 50, width: 800, height: 600)
        let to   = Rect(x: 100, y: 50, width: 800, height: 500)
        let m = calculateMovement(from: from, change: to)
        XCTAssertTrue(m.contains(.shrink))
        XCTAssertTrue(m.contains(.up))
    }

    // MARK: - Left edge resize (x changes, y stays)

    func testLeftEdgeGrow() {
        let from = Rect(x: 100, y: 50, width: 800, height: 600)
        let to   = Rect(x:  50, y: 50, width: 850, height: 600)
        let m = calculateMovement(from: from, change: to)
        XCTAssertTrue(m.contains(.grow))
        XCTAssertTrue(m.contains(.left))
    }

    func testLeftEdgeShrink() {
        let from = Rect(x: 100, y: 50, width: 800, height: 600)
        let to   = Rect(x: 150, y: 50, width: 750, height: 600)
        let m = calculateMovement(from: from, change: to)
        XCTAssertTrue(m.contains(.shrink))
        XCTAssertTrue(m.contains(.right))
    }

    // MARK: - Top edge resize (y changes, x stays)

    func testTopEdgeGrow() {
        let from = Rect(x: 100, y: 50, width: 800, height: 600)
        let to   = Rect(x: 100, y: 20, width: 800, height: 630)
        let m = calculateMovement(from: from, change: to)
        XCTAssertTrue(m.contains(.grow))
        XCTAssertTrue(m.contains(.up))
    }

    func testTopEdgeShrink() {
        let from = Rect(x: 100, y: 50, width: 800, height: 600)
        let to   = Rect(x: 100, y: 80, width: 800, height: 570)
        let m = calculateMovement(from: from, change: to)
        XCTAssertTrue(m.contains(.shrink))
        XCTAssertTrue(m.contains(.down))
    }

    // MARK: - Corner resize (both axes change)

    /// When both x and y change (corner resize), calculateMovement returns .moved.
    /// In onWindowResized (resize notification), .moved IS a resize — the check
    /// `movement != .moved` should NOT apply since we know it's a resize event.
    func testCornerResizeReturnsMoved() {
        let from = Rect(x: 100, y: 50, width: 800, height: 600)
        let to   = Rect(x:  50, y: 20, width: 850, height: 630)
        let m = calculateMovement(from: from, change: to)
        XCTAssertEqual(m, .moved,
                       "Corner resize where both axes change returns .moved")
    }

    // MARK: - expectedRect update after move (the fix)

    /// After onWindowMoved detects a user move, expectedRect is updated to
    /// the current position (not nil), so subsequent resize detection works.
    func testExpectedRectUpdatedAfterMove() {
        let movedRect = Rect(x: 100, y: 50, width: 800, height: 600)

        // After the fix, expectedRect = current position (not nil)
        let expectedRect: Rect? = movedRect

        // User resizes right edge
        let resizedRect = Rect(x: 100, y: 50, width: 900, height: 600)
        let fromRect = expectedRect ?? resizedRect
        let movement = calculateMovement(from: fromRect, change: resizedRect)

        XCTAssertTrue(movement.contains(.grow))
        XCTAssertTrue(movement.contains(.right))
        XCTAssertNotEqual(movement, .none,
                          "Must not silently ignore resize after a move")
    }

    /// Verify that when expectedRect is properly maintained, even a small
    /// resize is detected.
    func testSmallResizeDetected() {
        let from = Rect(x: 100, y: 50, width: 800, height: 600)
        let to   = Rect(x: 100, y: 50, width: 801, height: 600)
        let m = calculateMovement(from: from, change: to)
        XCTAssertTrue(m.contains(.grow))
        XCTAssertTrue(m.contains(.right))
    }

    // MARK: - Movement filter: .moved should not be discarded in resize context

    func testMovedFilterExcludesCornerResize() {
        let movement: Movement = .moved
        let wouldProcess = !movement.isEmpty && movement != .moved
        XCTAssertFalse(wouldProcess,
                       "Current code filters out .moved — corner resizes are lost")
    }

    // MARK: - Stacked (grouped) windows: ALL must be resized

    /// When a stack node is measured, ALL entities in the stack get recorded
    /// with the same rect. This ensures all grouped windows move together.
    func testStackNodeMeasureRecordsAllEntities() {
        let e1 = Entity(index: 1, generation: 0)
        let e2 = Entity(index: 2, generation: 0)
        let e3 = Entity(index: 3, generation: 0)
        let parent = Entity(index: 10, generation: 0)

        let stackData = StackData(idx: 0, entities: [e1, e2, e3])
        let node = Node(.stack(stackData))

        var recorded: [(Entity, Rect)] = []
        // Use a mock engine and tiler — measure only calls record for stack nodes
        let engine = Engine()
        let area = Rect(x: 0, y: 28, width: 1000, height: 700)

        node.measure(tiler: Forest(), engine: engine, parent: parent, area: area) { entity, _, rect in
            recorded.append((entity, rect))
        }

        // All 3 entities must be recorded
        XCTAssertEqual(recorded.count, 3,
                       "Stack measure must record ALL entities, not just the active one")
        let recordedEntities = Set(recorded.map { $0.0 })
        XCTAssertTrue(recordedEntities.contains(e1))
        XCTAssertTrue(recordedEntities.contains(e2))
        XCTAssertTrue(recordedEntities.contains(e3))
    }

    /// All entities in a stack get the SAME rect (minus tab bar height).
    func testStackNodeMeasureGivesSameRectToAll() {
        let e1 = Entity(index: 1, generation: 0)
        let e2 = Entity(index: 2, generation: 0)
        let parent = Entity(index: 10, generation: 0)

        let stackData = StackData(idx: 0, entities: [e1, e2])
        let node = Node(.stack(stackData))

        var recorded: [(Entity, Rect)] = []
        let engine = Engine()
        let area = Rect(x: 100, y: 0, width: 800, height: 600)

        node.measure(tiler: Forest(), engine: engine, parent: parent, area: area) { entity, _, rect in
            recorded.append((entity, rect))
        }

        XCTAssertEqual(recorded.count, 2)
        let rect1 = recorded[0].1
        let rect2 = recorded[1].1

        // Both must have the same rect
        XCTAssertEqual(rect1.x, rect2.x)
        XCTAssertEqual(rect1.y, rect2.y)
        XCTAssertEqual(rect1.width, rect2.width)
        XCTAssertEqual(rect1.height, rect2.height)

        // Stack area is offset by tab bar height (28)
        XCTAssertEqual(rect1.y, 28, "Stack area must be offset by tab bar height")
        XCTAssertEqual(rect1.height, 572, "Stack area height = 600 - 28 tab bar")
    }

    /// After resize, the Forest.requested map should contain ALL stacked entities
    /// so arrange() moves every grouped window.
    func testForestArrangeIncludesAllStackedWindows() {
        let forest = Forest()
        let engine = Engine()
        let e1 = Entity(index: 100_001, generation: 0)
        let e2 = Entity(index: 100_002, generation: 0)
        let e3 = Entity(index: 100_003, generation: 0)

        // Manually build: one fork with a stack on the left, single window on right
        let stackData = StackData(idx: 0, entities: [e1, e2, e3])
        let fork = Fork(entity: forest.createEntity(),
                        left: Node(.stack(stackData)),
                        right: nil,
                        area: Rect(x: 0, y: 0, width: 1000, height: 700),
                        workspace: 0, monitor: 0, orient: .horizontal)
        forest.forks.insert(fork.entity, fork)

        // Measure the fork — should record all 3 stacked entities
        fork.measure(tiler: forest, engine: engine, area: fork.area, record: forest.onRecord())

        // Check that all 3 entities are in the requested map
        let requestedEntities = Set(forest.requested.keys)
        XCTAssertTrue(requestedEntities.contains(e1),
                      "Stacked entity e1 must be in requested")
        XCTAssertTrue(requestedEntities.contains(e2),
                      "Stacked entity e2 must be in requested")
        XCTAssertTrue(requestedEntities.contains(e3),
                      "Stacked entity e3 must be in requested")
    }

    /// Stacked windows must all get the same rect after a resize measure.
    func testStackedWindowsGetSameRectAfterResize() {
        let forest = Forest()
        let engine = Engine()
        let e1 = Entity(index: 100_001, generation: 0)
        let e2 = Entity(index: 100_002, generation: 0)
        let eRight = Entity(index: 100_003, generation: 0)

        let stackData = StackData(idx: 0, entities: [e1, e2])
        let fork = Fork(entity: forest.createEntity(),
                        left: Node(.stack(stackData)),
                        right: Node(.window(eRight)),
                        area: Rect(x: 0, y: 0, width: 1000, height: 700),
                        workspace: 0, monitor: 0, orient: .horizontal)
        fork.setRatio(fork.length() / 2)
        forest.forks.insert(fork.entity, fork)

        fork.measure(tiler: forest, engine: engine, area: fork.area, record: forest.onRecord())

        // Both stacked entities must have the same rect
        guard let req1 = forest.requested[e1], let req2 = forest.requested[e2] else {
            XCTFail("Both stacked entities must be in requested")
            return
        }

        XCTAssertEqual(req1.rect.x, req2.rect.x)
        XCTAssertEqual(req1.rect.y, req2.rect.y)
        XCTAssertEqual(req1.rect.width, req2.rect.width)
        XCTAssertEqual(req1.rect.height, req2.rect.height)

        // The right window should have a different x position (it's on the right side)
        guard let reqRight = forest.requested[eRight] else {
            XCTFail("Right window must be in requested")
            return
        }
        XCTAssertGreaterThan(reqRight.rect.x, req1.rect.x,
                             "Right window should be to the right of the stack")
    }
}
