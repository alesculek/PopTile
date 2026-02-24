@testable import PopTileCore
import XCTest

final class ForkTests: XCTestCase {

    private func makeEntity(_ idx: Int) -> Entity {
        Entity(index: idx, generation: 0)
    }

    // MARK: - Basic properties

    func testHorizontalOrientation() {
        let fork = Fork(entity: makeEntity(0),
                        left: .window(makeEntity(1)),
                        right: .window(makeEntity(2)),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .horizontal)
        XCTAssertTrue(fork.isHorizontal())
        XCTAssertEqual(fork.length(), 1000)
        XCTAssertEqual(fork.depth(), 500)
    }

    func testVerticalOrientation() {
        let fork = Fork(entity: makeEntity(0),
                        left: .window(makeEntity(1)),
                        right: .window(makeEntity(2)),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .vertical)
        XCTAssertFalse(fork.isHorizontal())
        XCTAssertEqual(fork.length(), 500)
        XCTAssertEqual(fork.depth(), 1000)
    }

    // MARK: - setRatio

    func testSetRatioClampsMinimum() {
        let fork = Fork(entity: makeEntity(0),
                        left: .window(makeEntity(1)),
                        right: .window(makeEntity(2)),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .horizontal)
        fork.setRatio(10) // Too small
        XCTAssertTrue(fork.lengthLeft >= 250, "Should clamp to min(256, 1000/4)=250")
    }

    func testSetRatioClampsMaximum() {
        let fork = Fork(entity: makeEntity(0),
                        left: .window(makeEntity(1)),
                        right: .window(makeEntity(2)),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .horizontal)
        fork.setRatio(990) // Too large
        XCTAssertTrue(fork.lengthLeft <= 750, "Should clamp to max (forkLen - minLen)")
    }

    func testSetRatioNormalValue() {
        let fork = Fork(entity: makeEntity(0),
                        left: .window(makeEntity(1)),
                        right: .window(makeEntity(2)),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .horizontal)
        fork.setRatio(400)
        XCTAssertEqual(fork.lengthLeft, 400)
    }

    func testSetRatioZeroForkLength() {
        let fork = Fork(entity: makeEntity(0),
                        left: .window(makeEntity(1)),
                        right: nil,
                        area: Rect(x: 0, y: 0, width: 0, height: 0),
                        workspace: 0, monitor: 0, orient: .horizontal)
        // Should not crash
        fork.setRatio(100)
    }

    func testSetRatioSmallFork() {
        // For small forks, min = min(256, forkLen/4)
        let fork = Fork(entity: makeEntity(0),
                        left: .window(makeEntity(1)),
                        right: .window(makeEntity(2)),
                        area: Rect(x: 0, y: 0, width: 400, height: 300),
                        workspace: 0, monitor: 0, orient: .horizontal)
        fork.setRatio(50) // min(256, 100) = 100
        XCTAssertEqual(fork.lengthLeft, 100)
    }

    // MARK: - Orientation toggle

    func testToggleOrientation() {
        let fork = Fork(entity: makeEntity(0),
                        left: .window(makeEntity(1)),
                        right: .window(makeEntity(2)),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .horizontal)
        XCTAssertTrue(fork.isHorizontal())
        fork.toggleOrientation()
        XCTAssertFalse(fork.isHorizontal())
        XCTAssertTrue(fork.orientationChanged)
    }

    func testToggleTwiceSwapsBranches() {
        let e1 = makeEntity(1)
        let e2 = makeEntity(2)
        let fork = Fork(entity: makeEntity(0),
                        left: .window(e1),
                        right: .window(e2),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .horizontal)
        fork.toggleOrientation() // 1st toggle
        fork.toggleOrientation() // 2nd toggle — should swap branches
        // Back to horizontal, branches swapped
        XCTAssertTrue(fork.isHorizontal())
        XCTAssertTrue(fork.left.isWindow(e2))
    }

    // MARK: - Swap branches

    func testSwapBranches() {
        let e1 = makeEntity(1)
        let e2 = makeEntity(2)
        let fork = Fork(entity: makeEntity(0),
                        left: .window(e1),
                        right: .window(e2),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .horizontal)
        fork.swapBranches()
        XCTAssertTrue(fork.left.isWindow(e2))
        if let right = fork.right {
            XCTAssertTrue(right.isWindow(e1))
        } else {
            XCTFail("Right branch should exist after swap")
        }
    }

    func testSwapBranchesNoRight() {
        let e1 = makeEntity(1)
        let fork = Fork(entity: makeEntity(0),
                        left: .window(e1),
                        right: nil,
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .horizontal)
        fork.swapBranches() // Should not crash
        XCTAssertTrue(fork.left.isWindow(e1))
    }

    // MARK: - Rebalance orientation

    func testRebalanceOrientationWide() {
        let fork = Fork(entity: makeEntity(0),
                        left: .window(makeEntity(1)),
                        right: nil,
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .vertical)
        fork.rebalanceOrientation()
        XCTAssertTrue(fork.isHorizontal(), "Wide area should be horizontal")
    }

    func testRebalanceOrientationTall() {
        let fork = Fork(entity: makeEntity(0),
                        left: .window(makeEntity(1)),
                        right: nil,
                        area: Rect(x: 0, y: 0, width: 500, height: 1000),
                        workspace: 0, monitor: 0, orient: .horizontal)
        fork.rebalanceOrientation()
        XCTAssertFalse(fork.isHorizontal(), "Tall area should be vertical")
    }

    // MARK: - Initial lengthLeft

    func testInitialLengthLeftHorizontal() {
        let fork = Fork(entity: makeEntity(0),
                        left: .window(makeEntity(1)),
                        right: .window(makeEntity(2)),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .horizontal)
        XCTAssertEqual(fork.lengthLeft, 500, "Should be half of width for horizontal")
    }

    func testInitialLengthLeftVertical() {
        let fork = Fork(entity: makeEntity(0),
                        left: .window(makeEntity(1)),
                        right: .window(makeEntity(2)),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .vertical)
        XCTAssertEqual(fork.lengthLeft, 250, "Should be half of height for vertical")
    }

    // MARK: - findBranch

    func testFindBranchLeft() {
        let e1 = makeEntity(1)
        let e2 = makeEntity(2)
        let fork = Fork(entity: makeEntity(0),
                        left: .window(e1),
                        right: .window(e2),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .horizontal)
        let branch = fork.findBranch(e1)
        XCTAssertNotNil(branch)
        XCTAssertTrue(branch!.isWindow(e1))
    }

    func testFindBranchRight() {
        let e1 = makeEntity(1)
        let e2 = makeEntity(2)
        let fork = Fork(entity: makeEntity(0),
                        left: .window(e1),
                        right: .window(e2),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .horizontal)
        let branch = fork.findBranch(e2)
        XCTAssertNotNil(branch)
        XCTAssertTrue(branch!.isWindow(e2))
    }

    func testFindBranchNotFound() {
        let e1 = makeEntity(1)
        let e2 = makeEntity(2)
        let e3 = makeEntity(3)
        let fork = Fork(entity: makeEntity(0),
                        left: .window(e1),
                        right: .window(e2),
                        area: Rect(x: 0, y: 0, width: 1000, height: 500),
                        workspace: 0, monitor: 0, orient: .horizontal)
        XCTAssertNil(fork.findBranch(e3))
    }
}
