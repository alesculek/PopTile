@testable import PopTileCore
import XCTest

// MARK: - Drag-detach from stack: splitting vs stacking

/// When a user drags a window out of a stack to a split zone (left/right/top/bottom),
/// attachWindow should create a split fork alongside the stack — NOT re-join the stack.
/// When placeBy is .auto (auto-tiling), the existing attachStack behavior is preserved.
final class DragDetachStackTests: XCTestCase {

    private func makeEntity(_ idx: Int) -> Entity {
        Entity(index: idx, generation: 0)
    }

    /// Helper: set up a Forest with attached storage and onAttach/onDetach callbacks
    private func makeForestWithAttached() -> (Forest, Storage<Entity>) {
        let forest = Forest()
        let attached: Storage<Entity> = forest.registerStorage()

        forest.connectOnAttach { parent, child in
            attached.insert(child, parent)
        }
        forest.connectOnDetach { child in
            attached.remove(child)
        }

        return (forest, attached)
    }

    // MARK: - Cursor (drag) on stack should SPLIT

    /// Stack on left + window on right, cursor attach → creates sub-fork containing stack + new window
    func testCursorOnStackLeft_withRight_createsSplitFork() {
        let (forest, attached) = makeForestWithAttached()
        let engine = Engine()

        let winA = makeEntity(100_001)
        let winB = makeEntity(100_002)
        let winD = makeEntity(100_004)
        let winC = makeEntity(100_003) // new window to attach

        // Create a fork: stack(A,B) on left, window D on right
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)
        let stackData = StackData(idx: 999, entities: [winA, winB])
        let stackNode = Node(.stack(stackData))

        let (forkEntity, fork) = forest.createFork(
            left: stackNode, right: .window(winD), area: area,
            workspace: 0, monitor: 0)

        // Set up attached mappings
        forest.onAttach(forkEntity, winA)
        forest.onAttach(forkEntity, winB)
        forest.onAttach(forkEntity, winD)

        // Act: attach winC onto winA (which is in the stack) with cursor placement
        let result = forest.attachWindow(
            engine, ontoEntity: winA, newEntity: winC,
            placeBy: .cursor(orientation: .horizontal, swap: false),
            stackFromLeft: true)

        // Assert: should succeed (not nil)
        XCTAssertNotNil(result, "attachWindow with .cursor on stack should return non-nil")

        // The original fork's left should now be a sub-fork (not a stack)
        XCTAssertNotNil(fork.left.forkEntity,
                        "fork.left should be a sub-fork after split, not a stack")

        // The sub-fork should exist and contain the stack + new window
        if let subForkEntity = fork.left.forkEntity,
           let subFork = forest.forks.get(subForkEntity) {
            // One branch should be the stack, the other should be winC
            let leftIsStack = subFork.left.stackData != nil
            let rightIsWindow = subFork.right?.windowEntity == winC

            XCTAssertTrue(leftIsStack || (subFork.right?.stackData != nil),
                          "Sub-fork should contain the stack on one side")
            XCTAssertTrue(rightIsWindow || subFork.left.windowEntity == winC,
                          "Sub-fork should contain winC on one side")
        }

        // Stack entities should be re-attached to the sub-fork
        guard let subForkEntity = fork.left.forkEntity else {
            XCTFail("fork.left.forkEntity is nil — cannot verify attachments")
            return
        }
        XCTAssertEqual(attached.get(winA), subForkEntity,
                       "winA should be attached to the sub-fork")
        XCTAssertEqual(attached.get(winB), subForkEntity,
                       "winB should be attached to the sub-fork")
        XCTAssertEqual(attached.get(winC), subForkEntity,
                       "winC should be attached to the sub-fork")

        // winD should still be attached to the original fork
        XCTAssertEqual(attached.get(winD), forkEntity,
                       "winD should remain attached to the original fork")

        // Stack data should be unchanged (still contains A and B)
        XCTAssertEqual(stackData.entities.count, 2,
                       "Stack should still have 2 members after split")
        XCTAssertTrue(stackData.entities.contains(winA))
        XCTAssertTrue(stackData.entities.contains(winB))
    }

    /// Stack on left, no right branch, cursor attach → adds new window as fork.right
    func testCursorOnStackLeft_noRight_addsAsRight() {
        let (forest, attached) = makeForestWithAttached()
        let engine = Engine()

        let winA = makeEntity(100_001)
        let winB = makeEntity(100_002)
        let winC = makeEntity(100_003)

        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)
        let stackData = StackData(idx: 999, entities: [winA, winB])
        let stackNode = Node(.stack(stackData))

        let (forkEntity, fork) = forest.createFork(
            left: stackNode, right: nil, area: area,
            workspace: 0, monitor: 0)

        forest.onAttach(forkEntity, winA)
        forest.onAttach(forkEntity, winB)

        // Act: cursor attach winC alongside the stack
        let result = forest.attachWindow(
            engine, ontoEntity: winA, newEntity: winC,
            placeBy: .cursor(orientation: .horizontal, swap: false),
            stackFromLeft: true)

        XCTAssertNotNil(result, "attachWindow with .cursor on stack (no right) should succeed")

        // fork.left should still be the stack (no sub-fork needed)
        XCTAssertNotNil(fork.left.stackData,
                        "fork.left should remain the stack node")

        // fork.right should be the new window
        XCTAssertEqual(fork.right?.windowEntity, winC,
                       "fork.right should be winC")

        // winC attached to original fork
        XCTAssertEqual(attached.get(winC), forkEntity)

        // Stack unchanged
        XCTAssertEqual(stackData.entities.count, 2)
    }

    /// Stack on right branch, cursor attach → creates sub-fork on right side
    func testCursorOnStackRight_createsSplitFork() {
        let (forest, attached) = makeForestWithAttached()
        let engine = Engine()

        let winA = makeEntity(100_001) // left (plain window)
        let winB = makeEntity(100_002) // in stack on right
        let winD = makeEntity(100_004) // in stack on right
        let winC = makeEntity(100_003) // new window to attach

        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)
        let stackData = StackData(idx: 999, entities: [winB, winD])
        let stackNode = Node(.stack(stackData))

        let (forkEntity, fork) = forest.createFork(
            left: .window(winA), right: stackNode, area: area,
            workspace: 0, monitor: 0)

        forest.onAttach(forkEntity, winA)
        forest.onAttach(forkEntity, winB)
        forest.onAttach(forkEntity, winD)

        // Act: cursor attach winC onto winB (in right stack)
        let result = forest.attachWindow(
            engine, ontoEntity: winB, newEntity: winC,
            placeBy: .cursor(orientation: .vertical, swap: true),
            stackFromLeft: true)

        XCTAssertNotNil(result)

        // fork.right should now be a sub-fork
        XCTAssertNotNil(fork.right?.forkEntity,
                        "fork.right should be a sub-fork after splitting from stack")

        if let subForkEntity = fork.right?.forkEntity {
            XCTAssertEqual(attached.get(winB), subForkEntity)
            XCTAssertEqual(attached.get(winD), subForkEntity)
            XCTAssertEqual(attached.get(winC), subForkEntity)
        }

        // winA still on original fork
        XCTAssertEqual(attached.get(winA), forkEntity)
    }

    // MARK: - Auto placement on stack should still STACK (preserve existing behavior)

    /// With .auto placeBy, attachWindow on a stack target should route to attachStack.
    /// Since we don't have a full StackContainer in this test, attachStack returns nil,
    /// proving it took the stack path (not the split path).
    func testAutoOnStack_routesToAttachStack() {
        let (forest, _) = makeForestWithAttached()
        let engine = Engine()

        let winA = makeEntity(100_001)
        let winB = makeEntity(100_002)
        let winC = makeEntity(100_003)

        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)
        let stackData = StackData(idx: 999, entities: [winA, winB])
        let stackNode = Node(.stack(stackData))

        let (forkEntity, fork) = forest.createFork(
            left: stackNode, right: nil, area: area,
            workspace: 0, monitor: 0)

        forest.onAttach(forkEntity, winA)
        forest.onAttach(forkEntity, winB)

        // Act: auto-attach winC (should try attachStack, which fails without container)
        let result = forest.attachWindow(
            engine, ontoEntity: winA, newEntity: winC,
            placeBy: .auto,
            stackFromLeft: true)

        // attachStack returns nil because stacks.get(999) returns nil (no container)
        XCTAssertNil(result,
                     ".auto on stack should route to attachStack (returns nil without container)")

        // Fork structure should be unchanged (attachStack failed, no split happened)
        XCTAssertNotNil(fork.left.stackData,
                        "fork.left should still be the stack (no split)")
        XCTAssertNil(fork.right,
                     "fork.right should still be nil (nothing was added)")
    }

    // MARK: - Regression: cursor on plain window still splits correctly

    func testCursorOnPlainWindow_stillSplits() {
        let (forest, attached) = makeForestWithAttached()
        let engine = Engine()

        let winA = makeEntity(100_001)
        let winB = makeEntity(100_002)

        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)
        let (forkEntity, fork) = forest.createFork(
            left: .window(winA), right: nil, area: area,
            workspace: 0, monitor: 0)

        forest.onAttach(forkEntity, winA)

        let result = forest.attachWindow(
            engine, ontoEntity: winA, newEntity: winB,
            placeBy: .cursor(orientation: .horizontal, swap: false),
            stackFromLeft: true)

        XCTAssertNotNil(result)
        XCTAssertEqual(fork.right?.windowEntity, winB,
                       "Plain window attach with cursor should add as fork.right")
        XCTAssertEqual(attached.get(winB), forkEntity)
    }
}
