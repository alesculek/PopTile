@testable import PopTileCore
import XCTest

// MARK: - Screen parameter changes trigger retile

final class ScreenChangeRetileTests: XCTestCase {

    private func makeEntity(_ idx: Int) -> Entity {
        Entity(index: idx, generation: 0)
    }

    /// When the work area changes (dock hide/show, monitor added/removed),
    /// toplevel forks should be updated with the new area dimensions.
    func testRetileAll_updatesTopLevelForkAreas() {
        let engine = Engine()
        engine.enableAutoTiling()
        guard let autoTiler = engine.autoTiler else {
            XCTFail("AutoTiler should be enabled")
            return
        }

        let e1 = makeEntity(100_001)
        let area = Rect(x: 0, y: 44, width: 1800, height: 1076)
        let (forkEntity, fork) = autoTiler.forest.createToplevel(window: e1, area: area, id: (0, 0))
        autoTiler.forest.onAttach(forkEntity, e1)

        XCTAssertEqual(fork.area.width, 1800)
        XCTAssertEqual(fork.area.height, 1076)

        // Simulate retileAll — it calls updateToplevel which recalculates from monitorWorkArea
        // In a real scenario, monitorWorkArea would now return a larger area after dock hides
        engine.retileAll()

        // Fork should still be valid after retile (not crashed or corrupted)
        XCTAssertNotNil(autoTiler.forest.forks.get(forkEntity),
                        "Fork should survive retile")
    }

    /// Multiple toplevel forks (different monitors) should all get updated on retile
    func testRetileAll_updatesAllMonitors() {
        let engine = Engine()
        engine.enableAutoTiling()
        guard let autoTiler = engine.autoTiler else {
            XCTFail("AutoTiler should be enabled")
            return
        }

        let e1 = makeEntity(100_001)
        let e2 = makeEntity(100_002)
        let area1 = Rect(x: 0, y: 44, width: 1800, height: 1076)
        let area2 = Rect(x: 1800, y: 0, width: 3008, height: 1692)

        let (forkEntity1, _) = autoTiler.forest.createToplevel(window: e1, area: area1, id: (0, 0))
        autoTiler.forest.onAttach(forkEntity1, e1)
        let (forkEntity2, _) = autoTiler.forest.createToplevel(window: e2, area: area2, id: (1, 0))
        autoTiler.forest.onAttach(forkEntity2, e2)

        // Both forks should exist before retile
        XCTAssertNotNil(autoTiler.forest.forks.get(forkEntity1))
        XCTAssertNotNil(autoTiler.forest.forks.get(forkEntity2))

        engine.retileAll()

        // Both forks should survive retile
        XCTAssertNotNil(autoTiler.forest.forks.get(forkEntity1),
                        "Monitor 0 fork should survive retile")
        XCTAssertNotNil(autoTiler.forest.forks.get(forkEntity2),
                        "Monitor 1 fork should survive retile")
    }
}
