@testable import PopTileCore
import XCTest

// MARK: - Tab reorder in stack groups

final class TabReorderTests: XCTestCase {

    private func makeEntity(_ idx: Int) -> Entity {
        Entity(index: idx, generation: 0)
    }

    // MARK: - StackData.reorder

    func testStackDataReorder_moveToLater() {
        let e1 = makeEntity(1), e2 = makeEntity(2), e3 = makeEntity(3)
        let data = StackData(idx: 0, entities: [e1, e2, e3])

        data.reorder(from: 0, to: 2)

        XCTAssertEqual(data.entities.map(\.index), [2, 3, 1],
                       "Moving first to last should shift others left")
    }

    func testStackDataReorder_moveToEarlier() {
        let e1 = makeEntity(1), e2 = makeEntity(2), e3 = makeEntity(3)
        let data = StackData(idx: 0, entities: [e1, e2, e3])

        data.reorder(from: 2, to: 0)

        XCTAssertEqual(data.entities.map(\.index), [3, 1, 2],
                       "Moving last to first should shift others right")
    }

    func testStackDataReorder_sameIndex() {
        let e1 = makeEntity(1), e2 = makeEntity(2)
        let data = StackData(idx: 0, entities: [e1, e2])

        data.reorder(from: 1, to: 1)

        XCTAssertEqual(data.entities.map(\.index), [1, 2],
                       "Same index should be a no-op")
    }

    func testStackDataReorder_outOfBounds() {
        let e1 = makeEntity(1), e2 = makeEntity(2)
        let data = StackData(idx: 0, entities: [e1, e2])

        data.reorder(from: 5, to: 0)

        XCTAssertEqual(data.entities.map(\.index), [1, 2],
                       "Out of bounds should be a no-op")
    }

    func testStackDataReorder_adjacentSwap() {
        let e1 = makeEntity(1), e2 = makeEntity(2), e3 = makeEntity(3)
        let data = StackData(idx: 0, entities: [e1, e2, e3])

        data.reorder(from: 0, to: 1)

        XCTAssertEqual(data.entities.map(\.index), [2, 1, 3],
                       "Adjacent swap should work correctly")
    }

    func testStackDataReorder_fourElements() {
        let e1 = makeEntity(1), e2 = makeEntity(2), e3 = makeEntity(3), e4 = makeEntity(4)
        let data = StackData(idx: 0, entities: [e1, e2, e3, e4])

        data.reorder(from: 1, to: 3)

        XCTAssertEqual(data.entities.map(\.index), [1, 3, 4, 2],
                       "Moving middle to end should shift intermediate left")
    }

    // MARK: - StackContainer.reorderTab (activeId tracking)

    func testReorderTab_activeFollowsMovedTab() {
        let engine = Engine()
        let e1 = makeEntity(100_001)
        let container = StackContainer(engine: engine, active: e1, workspace: 0, monitor: 0)

        let e2 = makeEntity(100_002)
        let e3 = makeEntity(100_003)

        // Simulate adding tabs (without TileWindow, add to tabEntities directly)
        container.testAddEntity(e1)
        container.testAddEntity(e2)
        container.testAddEntity(e3)
        container.activeId = 0  // active is e1 at index 0

        // Move e1 from index 0 to index 2
        container.reorderTab(from: 0, to: 2)

        XCTAssertEqual(container.activeId, 2,
                       "Active tab should follow the moved tab")
        XCTAssertEqual(container.testTabEntities.map(\.index), [100_002, 100_003, 100_001])
    }

    func testReorderTab_activeShiftsWhenOtherMoved() {
        let engine = Engine()
        let e1 = makeEntity(100_001)
        let container = StackContainer(engine: engine, active: e1, workspace: 0, monitor: 0)

        let e2 = makeEntity(100_002)
        let e3 = makeEntity(100_003)

        container.testAddEntity(e1)
        container.testAddEntity(e2)
        container.testAddEntity(e3)
        container.activeId = 2  // active is e3 at index 2

        // Move e1 (index 0) past the active (to index 2)
        container.reorderTab(from: 0, to: 2)

        XCTAssertEqual(container.activeId, 1,
                       "Active should shift left when earlier tab moves past it")
    }

    func testReorderTab_activeShiftsWhenTabMovedBefore() {
        let engine = Engine()
        let e1 = makeEntity(100_001)
        let container = StackContainer(engine: engine, active: e1, workspace: 0, monitor: 0)

        let e2 = makeEntity(100_002)
        let e3 = makeEntity(100_003)

        container.testAddEntity(e1)
        container.testAddEntity(e2)
        container.testAddEntity(e3)
        container.activeId = 0  // active is e1 at index 0

        // Move e3 (index 2) before the active (to index 0)
        container.reorderTab(from: 2, to: 0)

        XCTAssertEqual(container.activeId, 1,
                       "Active should shift right when later tab moves before it")
    }

    // MARK: - StackData synced from StackContainer

    func testReorderTab_syncsToStackData() {
        let engine = Engine()
        let e1 = makeEntity(100_001)
        let container = StackContainer(engine: engine, active: e1, workspace: 0, monitor: 0)

        let e2 = makeEntity(100_002)
        let e3 = makeEntity(100_003)

        let data = StackData(idx: 0, entities: [e1, e2, e3])
        container.stackData = data

        container.testAddEntity(e1)
        container.testAddEntity(e2)
        container.testAddEntity(e3)

        container.reorderTab(from: 0, to: 2)

        XCTAssertEqual(data.entities.map(\.index), [100_002, 100_003, 100_001],
                       "StackData should be synced after reorder")
    }
}
