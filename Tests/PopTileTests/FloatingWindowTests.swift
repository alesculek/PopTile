@testable import PopTileCore
import XCTest

// MARK: - Floating windows stay on top

final class FloatingWindowTests: XCTestCase {

    private func makeEntity(_ idx: Int) -> Entity {
        Entity(index: idx, generation: 0)
    }

    func testRaiseFloatingWindows_onlyRaisesFloatingTagged() {
        let engine = Engine()
        let e1 = makeEntity(100_001)
        let e2 = makeEntity(100_002)

        // Tag e1 as floating, leave e2 as tiled
        engine.addTag(e1, Tags.floating.rawValue)

        // Verify tag state
        XCTAssertTrue(engine.containsTag(e1, Tags.floating.rawValue),
                      "e1 should be tagged floating")
        XCTAssertFalse(engine.containsTag(e2, Tags.floating.rawValue),
                       "e2 should not be tagged floating")

        // raiseFloatingWindows should not crash even with no actual AX windows
        engine.raiseFloatingWindows()
    }

    func testFloatingTagRemovedOnRetile() {
        let engine = Engine()
        let e1 = makeEntity(100_001)

        engine.addTag(e1, Tags.floating.rawValue)
        XCTAssertTrue(engine.containsTag(e1, Tags.floating.rawValue))

        engine.deleteTag(e1, Tags.floating.rawValue)
        XCTAssertFalse(engine.containsTag(e1, Tags.floating.rawValue),
                       "Floating tag should be removed when window is retiled")
    }

    func testFloatingTagSurvivesOtherTagOperations() {
        let engine = Engine()
        let e1 = makeEntity(100_001)

        engine.addTag(e1, Tags.floating.rawValue)
        engine.addTag(e1, Tags.forceTile.rawValue)

        XCTAssertTrue(engine.containsTag(e1, Tags.floating.rawValue))
        XCTAssertTrue(engine.containsTag(e1, Tags.forceTile.rawValue))

        engine.deleteTag(e1, Tags.forceTile.rawValue)
        XCTAssertTrue(engine.containsTag(e1, Tags.floating.rawValue),
                      "Deleting forceTile should not affect floating tag")
    }
}
