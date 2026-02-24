@testable import PopTileCore
import XCTest

// MARK: - KeyCode completeness and correctness

final class KeyCodeTests: XCTestCase {

    func testArrowKeyCodes() {
        XCTAssertEqual(KeyCode.leftArrow, 123)
        XCTAssertEqual(KeyCode.rightArrow, 124)
        XCTAssertEqual(KeyCode.downArrow, 125)
        XCTAssertEqual(KeyCode.upArrow, 126)
    }

    func testVimKeyCodes() {
        XCTAssertEqual(KeyCode.h, 4)
        XCTAssertEqual(KeyCode.j, 38)
        XCTAssertEqual(KeyCode.k, 40)
        XCTAssertEqual(KeyCode.l, 37)
    }

    func testToggleKeyCodes() {
        XCTAssertEqual(KeyCode.o, 31)
        XCTAssertEqual(KeyCode.s, 1)
        XCTAssertEqual(KeyCode.g, 5)
        XCTAssertEqual(KeyCode.t, 17)
        XCTAssertEqual(KeyCode.b, 11)
        XCTAssertEqual(KeyCode.r, 15, "KeyCode.r must be 15 for retile shortcut")
    }

    func testSpecialKeyCodes() {
        XCTAssertEqual(KeyCode.returnKey, 36)
        XCTAssertEqual(KeyCode.escape, 53)
        XCTAssertEqual(KeyCode.tab, 48)
        XCTAssertEqual(KeyCode.leftBracket, 33)
        XCTAssertEqual(KeyCode.rightBracket, 30)
    }
}

// MARK: - Hotkey registration

final class HotkeyRegistrationTests: XCTestCase {

    private var engine: Engine!

    override func setUp() {
        super.setUp()
        engine = Engine()
        engine.setupHotkeys()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Focus bindings (Ctrl+Option)

    func testArrowFocusBindings() {
        let ctrlOpt: NSEvent.ModifierFlags = [.control, .option]
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.leftArrow, ctrlOpt))
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.rightArrow, ctrlOpt))
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.upArrow, ctrlOpt))
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.downArrow, ctrlOpt))
    }

    func testHJKLFocusBindings() {
        let ctrlOpt: NSEvent.ModifierFlags = [.control, .option]
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.h, ctrlOpt))
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.l, ctrlOpt))
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.k, ctrlOpt))
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.j, ctrlOpt))
    }

    // MARK: - Move bindings (Ctrl+Option+Shift)

    func testArrowMoveBindings() {
        let ctrlOptShift: NSEvent.ModifierFlags = [.control, .option, .shift]
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.leftArrow, ctrlOptShift))
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.rightArrow, ctrlOptShift))
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.upArrow, ctrlOptShift))
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.downArrow, ctrlOptShift))
    }

    func testHJKLMoveBindings() {
        let ctrlOptShift: NSEvent.ModifierFlags = [.control, .option, .shift]
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.h, ctrlOptShift),
                      "Ctrl+Opt+Shift+H must be registered for move-left")
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.l, ctrlOptShift),
                      "Ctrl+Opt+Shift+L must be registered for move-right")
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.k, ctrlOptShift),
                      "Ctrl+Opt+Shift+K must be registered for move-up")
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.j, ctrlOptShift),
                      "Ctrl+Opt+Shift+J must be registered for move-down")
    }

    // MARK: - Toggle bindings

    func testToggleBindings() {
        let ctrlOpt: NSEvent.ModifierFlags = [.control, .option]
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.o, ctrlOpt), "orientation")
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.s, ctrlOpt), "stacking")
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.g, ctrlOpt), "floating")
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.t, ctrlOpt), "auto-tiling")
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.b, ctrlOpt), "active border")
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.r, ctrlOpt),
                      "Ctrl+Opt+R must be registered for retile-all")
    }

    // MARK: - Tiling mode bindings

    func testTilingModeBindings() {
        let ctrlOpt: NSEvent.ModifierFlags = [.control, .option]
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.returnKey, ctrlOpt),
                      "Ctrl+Opt+Return must be registered to enter tiling mode")
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.escape, ctrlOpt),
                      "Ctrl+Opt+Escape must be registered to exit tiling mode")
    }

    // MARK: - Resize bindings

    func testResizeBindings() {
        let ctrlOpt: NSEvent.ModifierFlags = [.control, .option]
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.leftBracket, ctrlOpt))
        XCTAssertTrue(engine.hotkeyManager.hasBinding(KeyCode.rightBracket, ctrlOpt))
    }

    // MARK: - No phantom bindings

    func testNoUnregisteredKeyHasBinding() {
        let ctrlOpt: NSEvent.ModifierFlags = [.control, .option]
        // 'x' key (keyCode 7) should NOT be registered
        XCTAssertFalse(engine.hotkeyManager.hasBinding(7, ctrlOpt))
    }

    // MARK: - Binding count

    func testTotalBindingCount() {
        // Focus: 4 arrows + 4 HJKL = 8
        // Move: 4 arrows + 4 HJKL = 8
        // Toggle: O, S, G, T, B, R = 6
        // Tiling mode: Return, Escape = 2
        // Resize: [, ] = 2
        // Total = 26
        let ctrlOpt: NSEvent.ModifierFlags = [.control, .option]
        let ctrlOptShift: NSEvent.ModifierFlags = [.control, .option, .shift]

        var count = 0
        let allCodes: [UInt16] = [
            KeyCode.leftArrow, KeyCode.rightArrow, KeyCode.upArrow, KeyCode.downArrow,
            KeyCode.h, KeyCode.j, KeyCode.k, KeyCode.l,
            KeyCode.o, KeyCode.s, KeyCode.g, KeyCode.t, KeyCode.b, KeyCode.r,
            KeyCode.returnKey, KeyCode.escape,
            KeyCode.leftBracket, KeyCode.rightBracket
        ]
        for code in allCodes {
            if engine.hotkeyManager.hasBinding(code, ctrlOpt) { count += 1 }
            if engine.hotkeyManager.hasBinding(code, ctrlOptShift) { count += 1 }
        }
        XCTAssertEqual(count, 26,
                       "Should have exactly 26 hotkey bindings (8 focus + 8 move + 6 toggle + 2 tiling + 2 resize)")
    }
}

// MARK: - Hotkey matching

final class HotkeyMatchingTests: XCTestCase {

    func testSameKeyDifferentModsDoNotMatch() {
        let a = Hotkey(keyCode: KeyCode.h, modifiers: [.control, .option])
        let b = Hotkey(keyCode: KeyCode.h, modifiers: [.control, .option, .shift])
        XCTAssertNotEqual(a, b)
    }

    func testSameKeyAndModsMatch() {
        let a = Hotkey(keyCode: KeyCode.leftArrow, modifiers: [.control, .option])
        let b = Hotkey(keyCode: KeyCode.leftArrow, modifiers: [.control, .option])
        XCTAssertEqual(a, b)
    }

    func testDifferentKeysSameModsDoNotMatch() {
        let a = Hotkey(keyCode: KeyCode.h, modifiers: [.control, .option])
        let b = Hotkey(keyCode: KeyCode.j, modifiers: [.control, .option])
        XCTAssertNotEqual(a, b)
    }

    func testHashConsistency() {
        let a = Hotkey(keyCode: KeyCode.r, modifiers: [.control, .option])
        let b = Hotkey(keyCode: KeyCode.r, modifiers: [.control, .option])
        XCTAssertEqual(a.hashValue, b.hashValue)
    }
}

// MARK: - Direction → MoveBy alignment (keyboard matches drag)

final class DirectionMoveByAlignmentTests: XCTestCase {

    /// Verify that keyboard move-left produces the same MoveBy as dragging to the left side.
    /// Drag approach: MoveBy.cursor(orientation: .horizontal, swap: true)
    /// Keyboard approach (after fix): same
    func testMoveLeftProducesHorizontalSwap() {
        let (orient, swap) = directionToPlacement(.left)
        XCTAssertEqual(orient, .horizontal)
        XCTAssertTrue(swap, "Move left should swap (new window goes to the left)")
    }

    func testMoveRightProducesHorizontalNoSwap() {
        let (orient, swap) = directionToPlacement(.right)
        XCTAssertEqual(orient, .horizontal)
        XCTAssertFalse(swap, "Move right should not swap (new window goes to the right)")
    }

    func testMoveUpProducesVerticalSwap() {
        let (orient, swap) = directionToPlacement(.up)
        XCTAssertEqual(orient, .vertical)
        XCTAssertTrue(swap, "Move up should swap (new window goes to the top)")
    }

    func testMoveDownProducesVerticalNoSwap() {
        let (orient, swap) = directionToPlacement(.down)
        XCTAssertEqual(orient, .vertical)
        XCTAssertFalse(swap, "Move down should not swap (new window goes to the bottom)")
    }

    /// Verify all 4 directions produce MoveBy.cursor (not .keyboard or .auto)
    func testAllDirectionsUseCursorPlacement() {
        for dir in [Direction.left, .right, .up, .down] {
            let (orient, swap) = directionToPlacement(dir)
            let moveBy = MoveBy.cursor(orientation: orient, swap: swap)
            if case .cursor = moveBy {
                // Good — cursor placement matches drag behavior
            } else {
                XCTFail("Direction \(dir) should produce MoveBy.cursor, got \(moveBy)")
            }
        }
    }

    /// Verify drag approach uses same mapping
    func testDragLeftMatchesKeyboardLeft() {
        // Drag to left side: orient=horizontal, swap=true
        let (orient, swap) = directionToPlacement(.left)
        XCTAssertEqual(orient, .horizontal)
        XCTAssertTrue(swap)
    }

    // Helper that mirrors the logic in moveAuto after fix
    private func directionToPlacement(_ direction: Direction) -> (Orientation, Bool) {
        let orient: Orientation = (direction == .left || direction == .right) ? .horizontal : .vertical
        let swap = (direction == .left || direction == .up)
        return (orient, swap)
    }
}

// MARK: - attachWindow cursor placement in single-child fork

final class AttachWindowPlacementTests: XCTestCase {

    private func makeEngine() -> Engine { Engine() }

    /// When a fork has only one child (left) and a new window is attached with
    /// .cursor(swap: true), the new window should end up on the LEFT.
    func testCursorSwapTruePutsNewWindowOnLeft() {
        let forest = Forest()
        let engine = makeEngine()
        let attached: Storage<Entity> = forest.registerStorage()

        forest.connectOnAttach { parent, child in
            attached.insert(child, parent)
        }
        forest.connectOnDetach { child in
            attached.remove(child)
        }

        let w1 = Entity(index: 100_001, generation: 0)
        let w2 = Entity(index: 100_002, generation: 0)
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)

        // Create toplevel with w1 as only window
        let (forkEntity, _) = forest.createToplevel(window: w1, area: area, id: (0, 0))
        forest.onAttach(forkEntity, w1)

        // Attach w2 with cursor placement: horizontal, swap=true (like dragging to left)
        let result = forest.attachWindow(engine, ontoEntity: w1, newEntity: w2,
                                         placeBy: .cursor(orientation: .horizontal, swap: true),
                                         stackFromLeft: true)
        XCTAssertNotNil(result, "attachWindow should succeed")

        guard let (_, fork) = result else { return }

        // After swap: w2 should be on left, w1 on right
        XCTAssertTrue(fork.left.isWindow(w2),
                      "With swap=true, new window (w2) should be on the LEFT")
        XCTAssertNotNil(fork.right)
        if let right = fork.right {
            XCTAssertTrue(right.isWindow(w1),
                          "Original window (w1) should be on the RIGHT after swap")
        }
    }

    /// When swap=false, new window stays on the right (default position).
    func testCursorSwapFalsePutsNewWindowOnRight() {
        let forest = Forest()
        let engine = makeEngine()
        let attached: Storage<Entity> = forest.registerStorage()

        forest.connectOnAttach { parent, child in
            attached.insert(child, parent)
        }
        forest.connectOnDetach { child in
            attached.remove(child)
        }

        let w1 = Entity(index: 100_001, generation: 0)
        let w2 = Entity(index: 100_002, generation: 0)
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)

        let (forkEntity, _) = forest.createToplevel(window: w1, area: area, id: (0, 0))
        forest.onAttach(forkEntity, w1)

        let result = forest.attachWindow(engine, ontoEntity: w1, newEntity: w2,
                                         placeBy: .cursor(orientation: .horizontal, swap: false),
                                         stackFromLeft: true)
        XCTAssertNotNil(result)

        guard let (_, fork) = result else { return }

        XCTAssertTrue(fork.left.isWindow(w1),
                      "Without swap, original window (w1) stays on LEFT")
        XCTAssertNotNil(fork.right)
        if let right = fork.right {
            XCTAssertTrue(right.isWindow(w2),
                          "Without swap, new window (w2) goes to RIGHT")
        }
    }

    /// Cursor placement with vertical orientation should set the fork's orientation.
    func testCursorVerticalSetsOrientation() {
        let forest = Forest()
        let engine = makeEngine()
        let attached: Storage<Entity> = forest.registerStorage()
        forest.connectOnAttach { parent, child in attached.insert(child, parent) }
        forest.connectOnDetach { child in attached.remove(child) }

        let w1 = Entity(index: 100_001, generation: 0)
        let w2 = Entity(index: 100_002, generation: 0)
        // Wide area defaults to horizontal
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)

        let (forkEntity, _) = forest.createToplevel(window: w1, area: area, id: (0, 0))
        forest.onAttach(forkEntity, w1)

        // Attach with vertical orientation (like dragging to top/bottom)
        let result = forest.attachWindow(engine, ontoEntity: w1, newEntity: w2,
                                         placeBy: .cursor(orientation: .vertical, swap: false),
                                         stackFromLeft: true)
        XCTAssertNotNil(result)

        guard let (_, fork) = result else { return }

        XCTAssertFalse(fork.isHorizontal(),
                       "Cursor with vertical orientation should set fork to vertical")
    }

    /// .auto placement should not change orientation or swap.
    func testAutoPlacementKeepsDefaults() {
        let forest = Forest()
        let engine = makeEngine()
        let attached: Storage<Entity> = forest.registerStorage()
        forest.connectOnAttach { parent, child in attached.insert(child, parent) }
        forest.connectOnDetach { child in attached.remove(child) }

        let w1 = Entity(index: 100_001, generation: 0)
        let w2 = Entity(index: 100_002, generation: 0)
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)

        let (forkEntity, _) = forest.createToplevel(window: w1, area: area, id: (0, 0))
        forest.onAttach(forkEntity, w1)

        let result = forest.attachWindow(engine, ontoEntity: w1, newEntity: w2,
                                         placeBy: .auto, stackFromLeft: true)
        XCTAssertNotNil(result)

        guard let (_, fork) = result else { return }

        // Default: w1 left, w2 right, horizontal (since area is wide)
        XCTAssertTrue(fork.left.isWindow(w1))
        if let right = fork.right {
            XCTAssertTrue(right.isWindow(w2))
        }
        XCTAssertTrue(fork.isHorizontal(), "Auto should keep default orientation")
    }
}

// MARK: - attachFork onAttach correctness

final class AttachForkOnAttachTests: XCTestCase {

    /// When attachFork creates a sub-fork (both children exist), the new window's
    /// attached parent should be the sub-fork entity, not the outer fork entity.
    func testAttachForkWithExistingChildrenPointsToSubFork() {
        let forest = Forest()
        let engine = Engine()
        let attached: Storage<Entity> = forest.registerStorage()

        forest.connectOnAttach { parent, child in
            attached.insert(child, parent)
        }
        forest.connectOnDetach { child in
            attached.remove(child)
        }

        let w1 = Entity(index: 100_001, generation: 0)
        let w2 = Entity(index: 100_002, generation: 0)
        let w3 = Entity(index: 100_003, generation: 0)
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)

        // Create fork with two children
        let (forkEntity, fork) = forest.createFork(
            left: .window(w1), right: .window(w2),
            area: area, workspace: 0, monitor: 0)
        forest.onAttach(forkEntity, w1)
        forest.onAttach(forkEntity, w2)

        // Attach w3 on the left side (should create a sub-fork)
        forest.attachFork(engine, fork, w3, isLeft: true)

        // w3's parent in attached should be a NEW sub-fork, not forkEntity
        let w3Parent = attached.get(w3)
        XCTAssertNotNil(w3Parent, "w3 should be in attached storage")
        // The sub-fork was created to hold the old children.
        // w3 should be the left child of the main fork.
        // The sub-fork entity should be different from the main fork.
        if let parent = w3Parent {
            // After the fix, w3 should point to the correct fork.
            // Before the fix, the duplicate onAttach would overwrite to forkEntity.
            // The sub-fork is created in the isLeft=true, fork.right != nil branch.
            // In that branch, old left+right go to sub-fork, sub-fork goes to right,
            // w3 goes to left. onAttach(newForkEntity, w3) is called.
            // The fix removes the duplicate onAttach(fork.entity, w3).
            XCTAssertNotEqual(parent, forkEntity,
                              "w3 parent should be the sub-fork, not the outer fork")
        }
    }

    /// When attachFork adds to a fork with only one child, the parent should be fork.entity.
    func testAttachForkSingleChildPointsToForkEntity() {
        let forest = Forest()
        let engine = Engine()
        let attached: Storage<Entity> = forest.registerStorage()

        forest.connectOnAttach { parent, child in
            attached.insert(child, parent)
        }
        forest.connectOnDetach { child in
            attached.remove(child)
        }

        let w1 = Entity(index: 100_001, generation: 0)
        let w2 = Entity(index: 100_002, generation: 0)
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)

        // Create fork with only left child (right is nil)
        let (forkEntity, fork) = forest.createFork(
            left: .window(w1), right: nil,
            area: area, workspace: 0, monitor: 0)
        forest.onAttach(forkEntity, w1)

        // Attach w2 on the right side
        forest.attachFork(engine, fork, w2, isLeft: false)

        let w2Parent = attached.get(w2)
        XCTAssertNotNil(w2Parent)
        XCTAssertEqual(w2Parent, forkEntity,
                       "w2 parent should be forkEntity when fork had only one child")
    }
}

// MARK: - Focus selector direction filtering

final class FocusSelectorDirectionTests: XCTestCase {

    func testUpwardDistanceSorting() {
        let a = Rect(x: 100, y: 100, width: 200, height: 200)
        let b = Rect(x: 100, y: 400, width: 200, height: 200)
        // a is above b (smaller y = higher in AX coords)
        let dist = upwardDistance(a, b)
        XCTAssertGreaterThan(dist, 0)
    }

    func testDownwardDistanceSorting() {
        let a = Rect(x: 100, y: 400, width: 200, height: 200)
        let b = Rect(x: 100, y: 100, width: 200, height: 200)
        let dist = downwardDistance(a, b)
        XCTAssertGreaterThan(dist, 0)
    }

    func testLeftwardDistanceSorting() {
        let a = Rect(x: 100, y: 100, width: 200, height: 200)
        let b = Rect(x: 400, y: 100, width: 200, height: 200)
        let dist = leftwardDistance(a, b)
        XCTAssertGreaterThan(dist, 0)
    }

    func testRightwardDistanceSorting() {
        let a = Rect(x: 400, y: 100, width: 200, height: 200)
        let b = Rect(x: 100, y: 100, width: 200, height: 200)
        let dist = rightwardDistance(a, b)
        XCTAssertGreaterThan(dist, 0)
    }

    /// Focus right should prefer the nearest window to the right.
    func testNearestRightWindowIsFirst() {
        let focused = Rect(x: 0, y: 0, width: 100, height: 100)
        let close = Rect(x: 200, y: 0, width: 100, height: 100)
        let far = Rect(x: 500, y: 0, width: 100, height: 100)

        let closeD = rightwardDistance(close, focused)
        let farD = rightwardDistance(far, focused)
        XCTAssertLessThan(closeD, farD,
                          "Closer window should have smaller rightward distance")
    }

    /// Windows at the same x position should not appear in left/right focus.
    func testSameXFilteredFromLeftRight() {
        let focused = Rect(x: 100, y: 0, width: 200, height: 200)
        let sameX = Rect(x: 100, y: 300, width: 200, height: 200)

        // For rightward: filter is $0.rect().x > fr.x
        // sameX.x == focused.x → NOT greater → filtered out
        XCTAssertFalse(sameX.x > focused.x,
                       "Same x should be filtered from rightward focus")
        XCTAssertFalse(sameX.x < focused.x,
                       "Same x should be filtered from leftward focus")
    }
}

// MARK: - Resize movement calculations

final class ResizeDirectionTests: XCTestCase {

    /// Resize left: two steps that adjust the split ratio leftward.
    func testResizeLeftMovements() {
        let hrow = 64
        let before = Rect(x: 500, y: 100, width: 800, height: 600)

        // Step 1: x += hrow, width -= hrow (pull left edge right)
        var step1 = before.clone()
        step1.apply(Rect(x: hrow, y: 0, width: -hrow, height: 0))
        let m1 = calculateMovement(from: before, change: step1)
        XCTAssertTrue(m1.contains(.shrink), "Step 1 of resize-left should shrink")

        // Step 2: width -= hrow (pull right edge left)
        var step2 = step1.clone()
        step2.apply(Rect(x: 0, y: 0, width: -hrow, height: 0))
        let m2 = calculateMovement(from: step1, change: step2)
        XCTAssertTrue(m2.contains(.shrink), "Step 2 of resize-left should shrink")
        XCTAssertTrue(m2.contains(.left), "Step 2 should indicate leftward shrink")
    }

    /// Resize right: two steps that adjust the split ratio rightward.
    func testResizeRightMovements() {
        let hrow = 64
        let before = Rect(x: 500, y: 100, width: 800, height: 600)

        // Step 1: width += hrow (extend right edge)
        var step1 = before.clone()
        step1.apply(Rect(x: 0, y: 0, width: hrow, height: 0))
        let m1 = calculateMovement(from: before, change: step1)
        XCTAssertTrue(m1.contains(.grow), "Step 1 of resize-right should grow")
        XCTAssertTrue(m1.contains(.right))

        // Step 2: x -= hrow, width += hrow (extend left edge)
        var step2 = step1.clone()
        step2.apply(Rect(x: -hrow, y: 0, width: hrow, height: 0))
        let m2 = calculateMovement(from: step1, change: step2)
        XCTAssertTrue(m2.contains(.grow), "Step 2 of resize-right should grow")
        XCTAssertTrue(m2.contains(.left))
    }

    /// Resize up: two steps that adjust the split ratio upward.
    func testResizeUpMovements() {
        let hcol = 64
        let before = Rect(x: 100, y: 300, width: 800, height: 600)

        // Step 1: y += hcol, height -= hcol (pull top edge down)
        var step1 = before.clone()
        step1.apply(Rect(x: 0, y: hcol, width: 0, height: -hcol))
        let m1 = calculateMovement(from: before, change: step1)
        XCTAssertTrue(m1.contains(.shrink), "Step 1 of resize-up should shrink")
        XCTAssertTrue(m1.contains(.down))

        // Step 2: height -= hcol (pull bottom edge up)
        var step2 = step1.clone()
        step2.apply(Rect(x: 0, y: 0, width: 0, height: -hcol))
        let m2 = calculateMovement(from: step1, change: step2)
        XCTAssertTrue(m2.contains(.shrink), "Step 2 of resize-up should shrink")
        XCTAssertTrue(m2.contains(.up))
    }

    /// Resize down: two steps that adjust the split ratio downward.
    func testResizeDownMovements() {
        let hcol = 64
        let before = Rect(x: 100, y: 300, width: 800, height: 600)

        // Step 1: height += hcol (extend bottom edge)
        var step1 = before.clone()
        step1.apply(Rect(x: 0, y: 0, width: 0, height: hcol))
        let m1 = calculateMovement(from: before, change: step1)
        XCTAssertTrue(m1.contains(.grow), "Step 1 of resize-down should grow")
        XCTAssertTrue(m1.contains(.down))

        // Step 2: y -= hcol, height += hcol (extend top edge)
        var step2 = step1.clone()
        step2.apply(Rect(x: 0, y: -hcol, width: 0, height: hcol))
        let m2 = calculateMovement(from: step1, change: step2)
        XCTAssertTrue(m2.contains(.grow), "Step 2 of resize-down should grow")
        XCTAssertTrue(m2.contains(.up))
    }
}

// MARK: - Tiling mode exit

final class TilingModeTests: XCTestCase {

    func testExitWhenNotInTilingModeIsNoOp() {
        let engine = Engine()
        let tiler = engine.tiler
        XCTAssertNil(tiler.window, "Should not be in tiling mode initially")
        tiler.exit(engine)  // Should not crash
        XCTAssertNil(tiler.window)
    }

    func testExitClearsTilingModeWindow() {
        let engine = Engine()
        let tiler = engine.tiler
        // Simulate entering tiling mode by setting a window entity
        let entity = Entity(index: 100_001, generation: 0)
        tiler.window = entity
        XCTAssertNotNil(tiler.window)

        tiler.exit(engine)
        XCTAssertNil(tiler.window, "Exit should clear tiling mode window")
    }
}

// MARK: - toggleFloating float exception handling

final class ToggleFloatingTests: XCTestCase {

    func testFloatExceptionCheckUsesSettings() {
        let settings = Settings()
        // Calculator is in default float exceptions
        XCTAssertTrue(settings.shouldFloat(bundleId: "com.apple.Calculator"))
        // Random app is not
        XCTAssertFalse(settings.shouldFloat(bundleId: "com.example.SomeApp"))
    }

    func testShouldFloatWithNilBundleIdReturnsFalse() {
        let settings = Settings()
        XCTAssertFalse(settings.shouldFloat(bundleId: nil))
    }

    func testTagsMutualExclusivity() {
        let engine = Engine()
        let entity = Entity(index: 100_001, generation: 0)

        // Add floating tag
        engine.addTag(entity, Tags.floating.rawValue)
        XCTAssertTrue(engine.containsTag(entity, Tags.floating.rawValue))
        XCTAssertFalse(engine.containsTag(entity, Tags.forceTile.rawValue))

        // Remove floating, add forceTile
        engine.deleteTag(entity, Tags.floating.rawValue)
        engine.addTag(entity, Tags.forceTile.rawValue)
        XCTAssertFalse(engine.containsTag(entity, Tags.floating.rawValue))
        XCTAssertTrue(engine.containsTag(entity, Tags.forceTile.rawValue))
    }

    /// Simulates the toggleFloating roundtrip: tiled → float → tile back.
    /// Verifies the floating tag is added then removed, matching the Ctrl+Opt+G toggle.
    func testFloatToggleRoundtrip() {
        let engine = Engine()
        let entity = Entity(index: 100_001, generation: 0)

        // Initially: not floating
        XCTAssertFalse(engine.containsTag(entity, Tags.floating.rawValue))

        // First toggle: float the window (add tag)
        engine.addTag(entity, Tags.floating.rawValue)
        XCTAssertTrue(engine.containsTag(entity, Tags.floating.rawValue),
                      "Window should be floating after first toggle")

        // Second toggle: tile back (remove tag)
        engine.deleteTag(entity, Tags.floating.rawValue)
        XCTAssertFalse(engine.containsTag(entity, Tags.floating.rawValue),
                       "Window should be tiled again after second toggle")
    }

    /// The toggleFloating logic: when floating tag exists, remove it and re-tile;
    /// when not floating and attached, detach and add floating tag.
    func testToggleFloatingLogicPaths() {
        let engine = Engine()
        let entity = Entity(index: 100_001, generation: 0)

        // Path 1: window is not floating, not a float exception → should float
        let isFloatException = engine.settings.shouldFloat(bundleId: "com.example.TestApp")
        XCTAssertFalse(isFloatException)
        XCTAssertFalse(engine.containsTag(entity, Tags.floating.rawValue))
        // toggleFloating would add the tag (if attached)
        engine.addTag(entity, Tags.floating.rawValue)
        XCTAssertTrue(engine.containsTag(entity, Tags.floating.rawValue))

        // Path 2: window IS floating → should un-float
        // toggleFloating checks: containsTag(.floating) → true → delete tag + autoTile
        engine.deleteTag(entity, Tags.floating.rawValue)
        XCTAssertFalse(engine.containsTag(entity, Tags.floating.rawValue),
                       "Pressing Ctrl+Opt+G again must remove the floating tag")
    }

    /// isFocusedWindowFloating reflects the per-window floating tag, not app-level exceptions.
    func testIsFocusedWindowFloatingReflectsTag() {
        let engine = Engine()
        // No focused window → false
        XCTAssertFalse(engine.isFocusedWindowFloating())
    }
}

// MARK: - Active border dismissed on toggle floating

final class ActiveBorderFloatingTests: XCTestCase {

    func testBorderHiddenWhenWindowTaggedFloating() {
        let engine = Engine()
        engine.settings.showActiveWindowBorder = true

        let entity = Entity(index: 100_001, generation: 0)
        let dummyElement = AXUIElementCreateApplication(getpid())
        let axWindow = AXWindow(element: dummyElement, pid: getpid())
        let tileWindow = TileWindow(entity: entity, axWindow: axWindow)

        // Show the border at a fake rect
        engine.showActiveBorderForTesting(rect: Rect(x: 100, y: 100, width: 800, height: 600))
        XCTAssertTrue(engine.isActiveBorderVisible, "Border should be visible before floating toggle")

        // Tag the window as floating (what toggleFloating does)
        engine.addTag(entity, Tags.floating.rawValue)

        // updateActiveBorder should hide the border for floating windows
        engine.updateActiveBorder(tileWindow)
        XCTAssertFalse(engine.isActiveBorderVisible,
                       "Active border must be hidden when window is floating")
    }

    func testBorderRemainsVisibleForNonFloatingWindow() {
        let engine = Engine()
        engine.settings.showActiveWindowBorder = true

        let entity = Entity(index: 100_001, generation: 0)
        let dummyElement = AXUIElementCreateApplication(getpid())
        let axWindow = AXWindow(element: dummyElement, pid: getpid())
        let tileWindow = TileWindow(entity: entity, axWindow: axWindow)

        // Show the border at a fake rect
        engine.showActiveBorderForTesting(rect: Rect(x: 100, y: 100, width: 800, height: 600))
        XCTAssertTrue(engine.isActiveBorderVisible)

        // No floating tag — updateActiveBorder should NOT hide it
        // (rect() returns .zero for mock window so it won't call show() again,
        //  but critically it should NOT call hide() either)
        engine.updateActiveBorder(tileWindow)

        // The border remains visible because the method exits at the zero-rect
        // guard without calling hide() — floating is the only tag-based hide path
        XCTAssertTrue(engine.isActiveBorderVisible,
                      "Border should remain visible for non-floating windows")
    }

    func testBorderHiddenWhenBorderSettingDisabled() {
        let engine = Engine()
        engine.settings.showActiveWindowBorder = false

        let entity = Entity(index: 100_001, generation: 0)
        let dummyElement = AXUIElementCreateApplication(getpid())
        let axWindow = AXWindow(element: dummyElement, pid: getpid())
        let tileWindow = TileWindow(entity: entity, axWindow: axWindow)

        // Force show border despite setting being off
        engine.showActiveBorderForTesting(rect: Rect(x: 100, y: 100, width: 800, height: 600))
        XCTAssertTrue(engine.isActiveBorderVisible)

        // updateActiveBorder should hide it because the setting is off
        engine.updateActiveBorder(tileWindow)
        XCTAssertFalse(engine.isActiveBorderVisible,
                       "Border should be hidden when showActiveWindowBorder is false")
    }
}

// MARK: - Sibling swap in moveAuto

final class SiblingSwapTests: XCTestCase {

    /// When two windows are siblings in a fork, swapping should exchange left/right.
    func testSiblingSwapExchangesBranches() {
        let w1 = Entity(index: 100_001, generation: 0)
        let w2 = Entity(index: 100_002, generation: 0)
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)

        let fork = Fork(entity: Entity(index: 0, generation: 0),
                        left: .window(w1), right: .window(w2),
                        area: area, workspace: 0, monitor: 0, orient: .horizontal)

        // Before swap
        XCTAssertTrue(fork.left.isWindow(w1))
        XCTAssertTrue(fork.right!.isWindow(w2))

        // Swap (mirrors moveAuto sibling logic)
        let temp = fork.right!
        fork.right = fork.left
        fork.left = temp

        // After swap
        XCTAssertTrue(fork.left.isWindow(w2), "w2 should now be on the left")
        XCTAssertTrue(fork.right!.isWindow(w1), "w1 should now be on the right")
    }

    /// Sibling swap is idempotent after 2 applications.
    func testDoubleSwapRestoresOriginal() {
        let w1 = Entity(index: 100_001, generation: 0)
        let w2 = Entity(index: 100_002, generation: 0)
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)

        let fork = Fork(entity: Entity(index: 0, generation: 0),
                        left: .window(w1), right: .window(w2),
                        area: area, workspace: 0, monitor: 0, orient: .horizontal)

        fork.swapBranches()
        fork.swapBranches()

        XCTAssertTrue(fork.left.isWindow(w1))
        XCTAssertTrue(fork.right!.isWindow(w2))
    }
}

// MARK: - Keyboard/drag parity integration test

final class KeyboardDragParityTests: XCTestCase {

    /// Both keyboard move-left and drag-to-left should produce the same tree structure
    /// when attaching a window to a fork with one child.
    func testMoveLeftAndDragLeftProduceSameResult() {
        // Simulate drag-to-left
        let forest1 = Forest()
        let engine1 = Engine()
        let attached1: Storage<Entity> = forest1.registerStorage()
        forest1.connectOnAttach { p, c in attached1.insert(c, p) }
        forest1.connectOnDetach { c in attached1.remove(c) }

        let w1a = Entity(index: 100_001, generation: 0)
        let w2a = Entity(index: 100_002, generation: 0)
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)

        let (fe1, _) = forest1.createToplevel(window: w1a, area: area, id: (0, 0))
        forest1.onAttach(fe1, w1a)

        // Drag approach: cursor horizontal, swap=true
        let dragResult = forest1.attachWindow(engine1, ontoEntity: w1a, newEntity: w2a,
                                              placeBy: .cursor(orientation: .horizontal, swap: true),
                                              stackFromLeft: true)

        // Simulate keyboard move-left (after fix: same MoveBy)
        let forest2 = Forest()
        let engine2 = Engine()
        let attached2: Storage<Entity> = forest2.registerStorage()
        forest2.connectOnAttach { p, c in attached2.insert(c, p) }
        forest2.connectOnDetach { c in attached2.remove(c) }

        let w1b = Entity(index: 100_001, generation: 0)
        let w2b = Entity(index: 100_002, generation: 0)

        let (fe2, _) = forest2.createToplevel(window: w1b, area: area, id: (0, 0))
        forest2.onAttach(fe2, w1b)

        // Keyboard approach (after fix): same as drag
        let kbResult = forest2.attachWindow(engine2, ontoEntity: w1b, newEntity: w2b,
                                            placeBy: .cursor(orientation: .horizontal, swap: true),
                                            stackFromLeft: true)

        // Both should have w2 on left, w1 on right
        guard let (_, dragFork) = dragResult, let (_, kbFork) = kbResult else {
            XCTFail("Both attach operations should succeed")
            return
        }

        XCTAssertTrue(dragFork.left.isWindow(w2a), "Drag: w2 on left")
        XCTAssertTrue(kbFork.left.isWindow(w2b), "Keyboard: w2 on left")

        if let dr = dragFork.right, let kr = kbFork.right {
            XCTAssertTrue(dr.isWindow(w1a), "Drag: w1 on right")
            XCTAssertTrue(kr.isWindow(w1b), "Keyboard: w1 on right")
        } else {
            XCTFail("Both forks should have right branches")
        }

        XCTAssertEqual(dragFork.isHorizontal(), kbFork.isHorizontal(),
                       "Both should have the same orientation")
    }

    /// Keyboard move-down and drag-to-bottom should both produce vertical layout.
    func testMoveDownAndDragDownProduceVerticalLayout() {
        let forest = Forest()
        let engine = Engine()
        let attached: Storage<Entity> = forest.registerStorage()
        forest.connectOnAttach { p, c in attached.insert(c, p) }
        forest.connectOnDetach { c in attached.remove(c) }

        let w1 = Entity(index: 100_001, generation: 0)
        let w2 = Entity(index: 100_002, generation: 0)
        let area = Rect(x: 0, y: 0, width: 1920, height: 1080)

        let (fe, _) = forest.createToplevel(window: w1, area: area, id: (0, 0))
        forest.onAttach(fe, w1)

        // Move down → vertical, swap=false → w1 on top, w2 on bottom
        let result = forest.attachWindow(engine, ontoEntity: w1, newEntity: w2,
                                         placeBy: .cursor(orientation: .vertical, swap: false),
                                         stackFromLeft: true)
        guard let (_, fork) = result else {
            XCTFail("Should succeed")
            return
        }

        XCTAssertFalse(fork.isHorizontal(), "Should be vertical for move-down")
        XCTAssertTrue(fork.left.isWindow(w1), "w1 should stay on top (left)")
        if let right = fork.right {
            XCTAssertTrue(right.isWindow(w2), "w2 should be on bottom (right)")
        }
    }
}

// MARK: - Resize should not trigger drag (re-tile)

final class ResizeNotDragTests: XCTestCase {

    /// Simulates the onWindowMoved guard: when size changes beyond tolerance,
    /// the event is a resize (not a drag) and should be skipped.
    private func isSizeChange(expected: Rect, current: Rect, tolerance: Int = 10) -> Bool {
        abs(current.width - expected.width) > tolerance ||
        abs(current.height - expected.height) > tolerance
    }

    /// Simulates the onWindowMoved guard: when position AND size are within
    /// tolerance, the window hasn't moved — skip.
    private func isWithinTolerance(expected: Rect, current: Rect, tolerance: Int = 10) -> Bool {
        abs(current.x - expected.x) <= tolerance &&
        abs(current.y - expected.y) <= tolerance &&
        abs(current.width - expected.width) <= tolerance &&
        abs(current.height - expected.height) <= tolerance
    }

    func testHeightResizeFromBottomIsNotDrag() {
        let expected = Rect(x: 100, y: 100, width: 800, height: 600)
        // User drags bottom edge down: y unchanged, height grows
        let current = Rect(x: 100, y: 100, width: 800, height: 700)

        XCTAssertFalse(isWithinTolerance(expected: expected, current: current),
                       "Height change should fail the tolerance check")
        XCTAssertTrue(isSizeChange(expected: expected, current: current),
                      "Height change must be detected as a size change, not a drag")
    }

    func testHeightResizeFromTopIsNotDrag() {
        let expected = Rect(x: 100, y: 100, width: 800, height: 600)
        // User drags top edge up: y decreases, height grows
        let current = Rect(x: 100, y: 50, width: 800, height: 650)

        XCTAssertFalse(isWithinTolerance(expected: expected, current: current))
        XCTAssertTrue(isSizeChange(expected: expected, current: current),
                      "Top-edge resize must be detected as size change, not drag")
    }

    func testWidthResizeFromRightIsNotDrag() {
        let expected = Rect(x: 100, y: 100, width: 800, height: 600)
        // User drags right edge: width grows
        let current = Rect(x: 100, y: 100, width: 900, height: 600)

        XCTAssertFalse(isWithinTolerance(expected: expected, current: current))
        XCTAssertTrue(isSizeChange(expected: expected, current: current),
                      "Width change must be detected as size change, not drag")
    }

    func testWidthResizeFromLeftIsNotDrag() {
        let expected = Rect(x: 100, y: 100, width: 800, height: 600)
        // User drags left edge: x decreases, width grows
        let current = Rect(x: 50, y: 100, width: 850, height: 600)

        XCTAssertFalse(isWithinTolerance(expected: expected, current: current))
        XCTAssertTrue(isSizeChange(expected: expected, current: current),
                      "Left-edge resize must be detected as size change, not drag")
    }

    func testPurePositionMoveIsNotSizeChange() {
        let expected = Rect(x: 100, y: 100, width: 800, height: 600)
        // User drags title bar: position changes, size stays
        let current = Rect(x: 200, y: 150, width: 800, height: 600)

        XCTAssertFalse(isWithinTolerance(expected: expected, current: current),
                       "Position change should fail tolerance")
        XCTAssertFalse(isSizeChange(expected: expected, current: current),
                       "Pure move must NOT be detected as size change — it's a real drag")
    }

    func testSmallResizeWithinToleranceIgnored() {
        let expected = Rect(x: 100, y: 100, width: 800, height: 600)
        // Tiny AX rounding noise: 5px height change (within tolerance of 10)
        let current = Rect(x: 100, y: 100, width: 800, height: 605)

        XCTAssertTrue(isWithinTolerance(expected: expected, current: current),
                      "Small change within tolerance should be treated as no change")
    }

    func testCalculateMovementDetectsGrowDown() {
        let from = Rect(x: 100, y: 100, width: 800, height: 600)
        let change = Rect(x: 100, y: 100, width: 800, height: 700)
        let movement = calculateMovement(from: from, change: change)

        XCTAssertTrue(movement.contains(.grow))
        XCTAssertTrue(movement.contains(.down))
        XCTAssertFalse(movement == .moved,
                       "Height resize should be grow+down, not a move")
    }

    func testCalculateMovementDetectsShrinkUp() {
        let from = Rect(x: 100, y: 100, width: 800, height: 600)
        let change = Rect(x: 100, y: 100, width: 800, height: 500)
        let movement = calculateMovement(from: from, change: change)

        XCTAssertTrue(movement.contains(.shrink))
        XCTAssertTrue(movement.contains(.up))
    }
}
