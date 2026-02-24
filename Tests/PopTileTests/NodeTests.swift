@testable import PopTileCore
import XCTest

final class NodeTests: XCTestCase {

    private func makeEntity(_ idx: Int) -> Entity {
        Entity(index: idx, generation: 0)
    }

    // MARK: - Window node

    func testWindowNode() {
        let e = makeEntity(1)
        let node = Node.window(e)
        XCTAssertTrue(node.isWindow(e))
        XCTAssertFalse(node.isWindow(makeEntity(2)))
        XCTAssertFalse(node.isFork(e))
        XCTAssertFalse(node.isInStack(e))
        XCTAssertEqual(node.windowEntity, e)
        XCTAssertNil(node.forkEntity)
        XCTAssertNil(node.stackData)
    }

    // MARK: - Fork node

    func testForkNode() {
        let e = makeEntity(1)
        let node = Node.fork(e)
        XCTAssertTrue(node.isFork(e))
        XCTAssertFalse(node.isWindow(e))
        XCTAssertEqual(node.forkEntity, e)
        XCTAssertNil(node.windowEntity)
    }

    // MARK: - Stack node

    func testStackNode() {
        let e = makeEntity(1)
        let node = Node.stacked(e, 0)
        XCTAssertTrue(node.isInStack(e))
        XCTAssertFalse(node.isInStack(makeEntity(2)))
        XCTAssertFalse(node.isWindow(e))
        XCTAssertFalse(node.isFork(e))
        XCTAssertNotNil(node.stackData)
        XCTAssertEqual(node.stackData?.entities.count, 1)
        XCTAssertEqual(node.stackData?.entities.first, e)
    }

    // MARK: - StackData

    func testStackDataMultipleEntities() {
        let e1 = makeEntity(1)
        let e2 = makeEntity(2)
        let data = StackData(idx: 0, entities: [e1, e2])
        XCTAssertEqual(data.entities.count, 2)
        XCTAssertEqual(data.idx, 0)
        XCTAssertNil(data.rect)
    }

    func testStackFind() {
        let e1 = makeEntity(1)
        let e2 = makeEntity(2)
        let e3 = makeEntity(3)
        let data = StackData(idx: 0, entities: [e1, e2])
        XCTAssertEqual(stackFind(data, e1), 0)
        XCTAssertEqual(stackFind(data, e2), 1)
        XCTAssertNil(stackFind(data, e3))
    }

    // MARK: - Auto-unstack scenario

    /// When a stack has only 1 entity, it should be convertible back to a window node
    func testSingleEntityStackShouldBeUnstackable() {
        let e = makeEntity(1)
        let data = StackData(idx: 0, entities: [e])
        // This is the condition checked in Forest.detach for auto-unstack
        XCTAssertEqual(data.entities.count, 1, "Stack with 1 entity should trigger auto-unstack")
    }
}
