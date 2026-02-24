@testable import PopTileCore
import XCTest

final class AutoTilerTests: XCTestCase {

    private func makeEntity(_ idx: Int) -> Entity {
        Entity(index: idx, generation: 0)
    }

    // MARK: - Forest toplevel

    func testCreateToplevelRegistersInMap() {
        let forest = Forest()
        let e = makeEntity(1)
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)
        let (entity, fork) = forest.createToplevel(window: e, area: area, id: (0, 0))
        XCTAssertTrue(fork.isToplevel)
        XCTAssertEqual(fork.monitor, 0)
        XCTAssertEqual(fork.workspace, 0)
        XCTAssertNotNil(forest.findToplevel((0, 0)))
    }

    func testSeparateToplevelsPerMonitor() {
        let forest = Forest()
        let e1 = makeEntity(1)
        let e2 = makeEntity(2)
        let area0 = Rect(x: 0, y: 0, width: 1920, height: 1080)
        let area1 = Rect(x: 1920, y: 0, width: 2560, height: 1440)

        _ = forest.createToplevel(window: e1, area: area0, id: (0, 0))
        _ = forest.createToplevel(window: e2, area: area1, id: (1, 0))

        let top0 = forest.findToplevel((0, 0))
        let top1 = forest.findToplevel((1, 0))
        XCTAssertNotNil(top0)
        XCTAssertNotNil(top1)
        XCTAssertNotEqual(top0, top1)
    }

    func testFindToplevelReturnsNilForMissing() {
        let forest = Forest()
        XCTAssertNil(forest.findToplevel((5, 0)))
    }

    // MARK: - Attached storage

    func testAttachedStorageTracksEntities() {
        let forest = Forest()
        let attached: Storage<Entity> = forest.registerStorage()

        forest.connectOnAttach { parent, child in
            attached.insert(child, parent)
        }
        forest.connectOnDetach { child in
            attached.remove(child)
        }

        let e1 = makeEntity(1)
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)
        let (entity, _) = forest.createToplevel(window: e1, area: area, id: (0, 0))

        // Manually trigger onAttach (normally done by createToplevel internals)
        forest.onAttach(entity, e1)
        XCTAssertTrue(attached.contains(e1))

        forest.onDetach(e1)
        XCTAssertFalse(attached.contains(e1))
    }

    // MARK: - Fork creation

    func testCreateForkSetsOrientation() {
        let forest = Forest()
        let e = makeEntity(1)

        // Wide area → horizontal
        let (_, fork1) = forest.createFork(
            left: .window(e), right: nil,
            area: Rect(x: 0, y: 0, width: 1920, height: 1080),
            workspace: 0, monitor: 0)
        XCTAssertTrue(fork1.isHorizontal())

        // Tall area → vertical
        let (_, fork2) = forest.createFork(
            left: .window(e), right: nil,
            area: Rect(x: 0, y: 0, width: 500, height: 1000),
            workspace: 0, monitor: 0)
        XCTAssertFalse(fork2.isHorizontal())
    }

    // MARK: - Tags

    func testTagsEnum() {
        XCTAssertEqual(Tags.floating.rawValue, 1)
        XCTAssertEqual(Tags.tiled.rawValue, 2)
        XCTAssertEqual(Tags.forceTile.rawValue, 3)
    }
}
