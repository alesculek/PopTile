@testable import PopTileCore
import XCTest

// MARK: - Task 1: Tab bar height

final class TabBarHeightTests: XCTestCase {

    private func makeEntity(_ idx: Int) -> Entity {
        Entity(index: idx, generation: 0)
    }

    func testStackContainerTabHeight_is28() {
        let engine = Engine()
        let e = makeEntity(100_001)
        let container = StackContainer(engine: engine, active: e, workspace: 0, monitor: 0)
        XCTAssertEqual(container.tabsHeight, 28,
                       "Tab bar height should be 28pt for comfortable reading")
    }

    func testNodeMeasureStack_subtractsTabBarHeight() {
        let engine = Engine()
        engine.enableAutoTiling()

        let e1 = makeEntity(100_001)
        let e2 = makeEntity(100_002)
        let data = StackData(idx: 0, entities: [e1, e2])
        let node = Node(.stack(data))

        let parent = makeEntity(0)
        let area = Rect(x: 100, y: 100, width: 800, height: 600)
        var recorded: [(Entity, Rect)] = []

        node.measure(tiler: engine.autoTiler!.forest, engine: engine, parent: parent, area: area) {
            entity, _, rect in
            recorded.append((entity, rect))
        }

        // Each stacked window should be placed below the tab bar
        for (_, rect) in recorded {
            XCTAssertEqual(rect.y, 100 + 28,
                           "Stack area should start 28pt below the allocated area top")
            XCTAssertEqual(rect.height, 600 - 28,
                           "Stack area should be 28pt shorter than the allocated area")
            XCTAssertEqual(rect.x, 100)
            XCTAssertEqual(rect.width, 800)
        }

        // StackData.rect should also reflect the reduced area
        XCTAssertEqual(data.rect?.y, 100 + 28)
        XCTAssertEqual(data.rect?.height, 600 - 28)
    }

    func testNodeMeasureStack_tabHeightConsistent() {
        // Tab bar height in Node.measure must match StackContainer.tabsHeight
        let engine = Engine()
        let e = makeEntity(100_001)
        let container = StackContainer(engine: engine, active: e, workspace: 0, monitor: 0)

        engine.enableAutoTiling()

        let data = StackData(idx: 0, entities: [e])
        let node = Node(.stack(data))
        let parent = makeEntity(0)
        let area = Rect(x: 0, y: 0, width: 1000, height: 500)

        node.measure(tiler: engine.autoTiler!.forest, engine: engine, parent: parent, area: area) {
            _, _, rect in
            XCTAssertEqual(rect.y, container.tabsHeight,
                           "Node.measure tab height should match StackContainer.tabsHeight")
        }
    }
}

// MARK: - Task 2: Active window border setting

final class ActiveWindowBorderSettingTests: XCTestCase {

    private var settings: Settings!

    override func setUp() {
        super.setUp()
        settings = Settings()
        UserDefaults.standard.removeObject(forKey: "showActiveWindowBorder")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "showActiveWindowBorder")
        super.tearDown()
    }

    func testDefaultShowActiveWindowBorder_isFalse() {
        XCTAssertFalse(settings.showActiveWindowBorder,
                       "Active window border should be off by default")
    }

    func testShowActiveWindowBorder_persists() {
        settings.showActiveWindowBorder = true
        XCTAssertTrue(settings.showActiveWindowBorder)

        // Read from a fresh Settings instance to verify persistence
        let settings2 = Settings()
        XCTAssertTrue(settings2.showActiveWindowBorder)
    }

    func testShowActiveWindowBorder_toggleOff() {
        settings.showActiveWindowBorder = true
        XCTAssertTrue(settings.showActiveWindowBorder)
        settings.showActiveWindowBorder = false
        XCTAssertFalse(settings.showActiveWindowBorder)
    }
}

// MARK: - Task 2: ActiveWindowBorder overlay

final class ActiveWindowBorderOverlayTests: XCTestCase {

    func testActiveWindowBorder_initiallyHidden() {
        let border = ActiveWindowBorder()
        XCTAssertFalse(border.visible,
                       "Border should start hidden")
    }

    func testActiveWindowBorder_showAndHide() {
        let border = ActiveWindowBorder()
        let rect = Rect(x: 100, y: 100, width: 800, height: 600)

        border.update(rect: rect, color: .systemCyan)
        border.show()
        XCTAssertTrue(border.visible)

        border.hide()
        XCTAssertFalse(border.visible)
    }

    func testActiveWindowBorder_updateRect() {
        let border = ActiveWindowBorder()
        let rect1 = Rect(x: 0, y: 0, width: 500, height: 400)
        let rect2 = Rect(x: 100, y: 100, width: 800, height: 600)

        border.update(rect: rect1, color: .systemCyan)
        XCTAssertEqual(border.rect, rect1)

        border.update(rect: rect2, color: .systemCyan)
        XCTAssertEqual(border.rect, rect2)
    }
}
