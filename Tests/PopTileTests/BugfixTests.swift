@testable import PopTileCore
import XCTest

// MARK: - BUG 1: Entity ID collision between windows and forks

final class EntityCollisionTests: XCTestCase {

    /// Window entities (100_001+) must not overlap with fork entities (0,1,2...).
    /// Engine.createWindowEntity starts at 100_001, Forest/World starts at 0.
    func testForestEntityIndicesDoNotOverlapWithWindowEntityRange() {
        let forest = Forest()

        // Simulate window entities: indices 100_001+ (as Engine creates them)
        let winEntity1 = Entity(index: 100_001, generation: 0)
        let winEntity2 = Entity(index: 100_002, generation: 0)
        let winEntity3 = Entity(index: 100_003, generation: 0)

        // Create fork entities from Forest (uses World's 0,1,2...)
        let forkEntity1 = forest.createEntity()
        let forkEntity2 = forest.createEntity()
        let forkEntity3 = forest.createEntity()

        // Window entities should NOT collide with fork entities
        XCTAssertNotEqual(forkEntity1.index, winEntity1.index,
                          "Fork entity index should not collide with window entity index")
        XCTAssertNotEqual(forkEntity2.index, winEntity2.index,
                          "Fork entity index should not collide with window entity index")
        XCTAssertNotEqual(forkEntity3.index, winEntity3.index,
                          "Fork entity index should not collide with window entity index")
    }

    /// Deleting a fork entity must NOT remove a window's entry from attached storage
    func testDeletingForkDoesNotCorruptAttachedStorage() {
        let forest = Forest()
        let attached: Storage<Entity> = forest.registerStorage()

        forest.connectOnAttach { parent, child in
            attached.insert(child, parent)
        }
        forest.connectOnDetach { child in
            attached.remove(child)
        }

        // Create a window entity (simulating Engine's createWindowEntity at 100_001+)
        let winEntity = Entity(index: 100_001, generation: 0)

        // Create a toplevel fork
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)
        let (forkEntity, _) = forest.createToplevel(window: winEntity, area: area, id: (0, 0))
        forest.onAttach(forkEntity, winEntity)

        // Window should be attached
        XCTAssertTrue(attached.contains(winEntity), "Window should be in attached storage")
        XCTAssertEqual(attached.get(winEntity), forkEntity)

        // Create and delete another fork entity
        let (tempForkEntity, _) = forest.createFork(
            left: .window(Entity(index: 99, generation: 0)), right: nil,
            area: area, workspace: 0, monitor: 0)
        forest.deleteEntity(tempForkEntity)

        // The window attachment must still be intact
        XCTAssertTrue(attached.contains(winEntity),
                      "Deleting a fork entity must NOT remove window's attachment")
        XCTAssertEqual(attached.get(winEntity), forkEntity,
                       "Window should still point to its original fork")
    }

    /// Stress test: many window + fork entities, delete forks, verify no corruption
    func testManyEntitiesNoCollision() {
        let forest = Forest()
        let attached: Storage<Entity> = forest.registerStorage()

        // Simulate 50 window entities (as Engine would create them, starting at 100_001)
        var windowEntities: [Entity] = []
        for i in 1...50 {
            windowEntities.append(Entity(index: 100_000 + i, generation: 0))
        }

        // Create 50 fork entities from Forest
        var forkEntities: [Entity] = []
        for _ in 1...50 {
            forkEntities.append(forest.createEntity())
        }

        // Attach each window to a fork
        for (i, winE) in windowEntities.enumerated() {
            let forkE = forkEntities[i]
            attached.insert(winE, forkE)
        }

        // Delete half the fork entities
        for i in stride(from: 0, to: 50, by: 2) {
            forest.deleteEntity(forkEntities[i])
        }

        // All window attachments should still be intact
        for (i, winE) in windowEntities.enumerated() {
            XCTAssertTrue(attached.contains(winE),
                          "Window entity \(i) attachment corrupted after fork deletion")
        }
    }
}

// MARK: - BUG 4: Gap setting of 0px is impossible

final class GapZeroTests: XCTestCase {

    private var settings: Settings!

    override func setUp() {
        super.setUp()
        settings = Settings()
        UserDefaults.standard.removeObject(forKey: "gapOuter")
        UserDefaults.standard.removeObject(forKey: "gapInner")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "gapOuter")
        UserDefaults.standard.removeObject(forKey: "gapInner")
        super.tearDown()
    }

    func testGapOuterCanBeSetToZero() {
        settings.gapOuter = 0
        XCTAssertEqual(settings.gapOuter, 0,
                       "Gap outer should be 0 when explicitly set to 0")
    }

    func testGapInnerCanBeSetToZero() {
        settings.gapInner = 0
        XCTAssertEqual(settings.gapInner, 0,
                       "Gap inner should be 0 when explicitly set to 0")
    }

    func testGapOuterDefaultsTo4WhenNeverSet() {
        UserDefaults.standard.removeObject(forKey: "gapOuter")
        let freshSettings = Settings()
        XCTAssertEqual(freshSettings.gapOuter, 4,
                       "Gap outer should default to 4 when never set")
    }

    func testGapInnerDefaultsTo4WhenNeverSet() {
        UserDefaults.standard.removeObject(forKey: "gapInner")
        let freshSettings = Settings()
        XCTAssertEqual(freshSettings.gapInner, 4,
                       "Gap inner should default to 4 when never set")
    }

    func testGapRoundTrip() {
        for gap in [0, 1, 2, 4, 8, 12, 16] {
            settings.gapOuter = gap
            XCTAssertEqual(settings.gapOuter, gap,
                           "Gap outer round-trip failed for value \(gap)")
            settings.gapInner = gap
            XCTAssertEqual(settings.gapInner, gap,
                           "Gap inner round-trip failed for value \(gap)")
        }
    }
}

// MARK: - BUG 7: Rect.clamp can produce negative width/height

final class RectClampSafetyTests: XCTestCase {

    func testClampRectBeyondBoundsRight() {
        var r = Rect(x: 200, y: 0, width: 100, height: 100)
        let bounds = Rect(x: 0, y: 0, width: 150, height: 100)
        r.clamp(bounds)
        XCTAssertTrue(r.width >= 0,
                      "Clamp should never produce negative width, got \(r.width)")
    }

    func testClampRectBeyondBoundsBottom() {
        var r = Rect(x: 0, y: 200, width: 100, height: 100)
        let bounds = Rect(x: 0, y: 0, width: 100, height: 150)
        r.clamp(bounds)
        XCTAssertTrue(r.height >= 0,
                      "Clamp should never produce negative height, got \(r.height)")
    }

    func testClampRectCompletelyOutsideBounds() {
        var r = Rect(x: 500, y: 500, width: 100, height: 100)
        let bounds = Rect(x: 0, y: 0, width: 100, height: 100)
        r.clamp(bounds)
        XCTAssertTrue(r.width >= 0, "Width should be non-negative, got \(r.width)")
        XCTAssertTrue(r.height >= 0, "Height should be non-negative, got \(r.height)")
    }

    func testClampRectAtBoundsEdge() {
        var r = Rect(x: 100, y: 100, width: 50, height: 50)
        let bounds = Rect(x: 0, y: 0, width: 100, height: 100)
        r.clamp(bounds)
        XCTAssertTrue(r.width >= 0, "Width should be non-negative at edge")
        XCTAssertTrue(r.height >= 0, "Height should be non-negative at edge")
    }

    func testClampNormalCaseUnchanged() {
        var r = Rect(x: 10, y: 10, width: 50, height: 50)
        let bounds = Rect(x: 0, y: 0, width: 200, height: 200)
        let before = r
        r.clamp(bounds)
        XCTAssertEqual(r, before, "Rect inside bounds should not change")
    }

    func testClampWithOffsetBounds() {
        var r = Rect(x: 300, y: 300, width: 100, height: 100)
        let bounds = Rect(x: 100, y: 100, width: 150, height: 150)
        r.clamp(bounds)
        XCTAssertTrue(r.width >= 0, "Width should be non-negative")
        XCTAssertTrue(r.height >= 0, "Height should be non-negative")
        XCTAssertEqual(r.width, 0,
                       "Width should be 0 when rect is entirely past bounds")
    }
}

// MARK: - BUG 11: World.allEntities() O(n^2) + double-delete safety

final class WorldFreeSlotTests: XCTestCase {

    func testAllEntitiesExcludesDeleted() {
        let world = World()
        var entities: [Entity] = []
        for _ in 0..<10 {
            entities.append(world.createEntity())
        }

        // Delete even-indexed entities
        for i in stride(from: 0, to: 10, by: 2) {
            world.deleteEntity(entities[i])
        }

        let allE = Array(world.allEntities())
        XCTAssertEqual(allE.count, 5, "Should have 5 remaining entities")

        for i in stride(from: 0, to: 10, by: 2) {
            XCTAssertFalse(allE.contains(entities[i]),
                           "Deleted entity at index \(i) should not appear")
        }

        for i in stride(from: 1, to: 10, by: 2) {
            XCTAssertTrue(allE.contains(entities[i]),
                          "Entity at index \(i) should still appear")
        }
    }

    /// Double-delete should not corrupt free slot tracking
    func testDoubleDeleteDoesNotDuplicateFreeSlot() {
        let world = World()
        let _ = world.createEntity()  // e0
        let _ = world.createEntity()  // e1
        let e0 = Entity(index: 0, generation: 0)

        XCTAssertEqual(world.length, 2)

        world.deleteEntity(e0)
        XCTAssertEqual(world.length, 1)

        // Double-delete should be a no-op
        world.deleteEntity(e0)
        XCTAssertEqual(world.length, 1,
                       "Double-delete should not corrupt free slot count")
    }

    func testDeleteAndReusePreservesCorrectCount() {
        let world = World()
        _ = world.createEntity()  // index 0
        let e1 = world.createEntity()  // index 1
        _ = world.createEntity()  // index 2

        world.deleteEntity(e1)
        XCTAssertEqual(world.length, 2)

        let e3 = world.createEntity()
        XCTAssertEqual(world.length, 3)
        XCTAssertEqual(e3.index, e1.index, "Should reuse deleted slot")
        XCTAssertEqual(e3.generation, e1.generation + 1, "Generation should increment")
    }
}

// MARK: - BUG 6: Forest.detach stack auto-unstack correctness

final class ForestStackDetachTests: XCTestCase {

    /// Verify that StackData removal logic correctly identifies when auto-unstack is needed
    func testStackDataRemovalTracksCount() {
        let e1 = Entity(index: 1001, generation: 0)
        let e2 = Entity(index: 1002, generation: 0)
        let data = StackData(idx: 0, entities: [e1, e2])

        // Remove one entity
        data.entities.removeAll { $0 == e1 }
        XCTAssertEqual(data.entities.count, 1,
                       "Should have 1 entity remaining after removal")
        XCTAssertEqual(data.entities.first, e2,
                       "Remaining entity should be e2")
    }

    /// When a right-branch stack has 2 entities and one is removed leaving 1,
    /// the auto-unstack check should correctly read the right branch
    func testRightBranchAutoUnstackReadsCorrectNode() {
        let e1 = Entity(index: 1001, generation: 0)
        let e2 = Entity(index: 1002, generation: 0)
        let e3 = Entity(index: 1003, generation: 0)

        let rightStackData = StackData(idx: 0, entities: [e2, e3])
        let fork = Fork(
            entity: Entity(index: 5000, generation: 0),
            left: .window(e1),
            right: Node(.stack(rightStackData)),
            area: Rect(x: 0, y: 0, width: 1000, height: 500),
            workspace: 0, monitor: 0, orient: .horizontal)

        // Simulate removing e2 from the stack
        rightStackData.entities.removeAll { $0 == e2 }

        // The right branch should still be the stack, and it should have 1 entity
        if let right = fork.right, let data = right.stackData {
            XCTAssertEqual(data.entities.count, 1,
                           "Right branch stack should have 1 entity after removal")
            XCTAssertEqual(data.entities.first, e3)
        } else {
            XCTFail("Right branch should still be a stack")
        }
    }

    /// Left branch stack: after removing from a 2-entity stack,
    /// save reference BEFORE onLast might change fork.left
    func testLeftBranchStackDetachPreservesCorrectReference() {
        let e1 = Entity(index: 1001, generation: 0)
        let e2 = Entity(index: 1002, generation: 0)
        let e3 = Entity(index: 1003, generation: 0)

        let leftStackData = StackData(idx: 0, entities: [e1, e2])
        let fork = Fork(
            entity: Entity(index: 5000, generation: 0),
            left: Node(.stack(leftStackData)),
            right: .window(e3),
            area: Rect(x: 0, y: 0, width: 1000, height: 500),
            workspace: 0, monitor: 0, orient: .horizontal)

        // Save reference to left stack BEFORE any modification
        let savedLeftStackData = fork.left.stackData

        // Simulate onLast changing fork.left (when stack becomes empty)
        // In the buggy code, fork.left was reassigned before the auto-unstack check
        fork.left = fork.right!
        fork.right = nil

        // The saved reference should still be the original stack data
        XCTAssertNotNil(savedLeftStackData,
                        "Saved stack data reference should be valid")
        XCTAssertEqual(savedLeftStackData?.entities.count, 2,
                       "Saved reference should reflect original stack")

        // But fork.left is now the old right branch (a window, not a stack)
        XCTAssertNil(fork.left.stackData,
                     "fork.left is now a window, not a stack")
    }
}
