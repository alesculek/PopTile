// Tiler.swift — Keyboard-driven tiling mode + Focus selector
// Port of pop-shell src/tiling.ts and src/focus.ts

import Foundation

// MARK: - GrabOp

struct GrabOp {
    let entity: Entity
    var rect: Rect

    func operation(_ crect: Rect) -> Movement {
        calculateMovement(from: rect, change: crect)
    }
}

// MARK: - Focus Selector

final class FocusSelector {
    func down(_ engine: Engine, _ window: TileWindow?) -> TileWindow? {
        selectFn(engine, windowDown, window)
    }

    func left(_ engine: Engine, _ window: TileWindow?) -> TileWindow? {
        selectFn(engine, windowLeft, window)
    }

    func right(_ engine: Engine, _ window: TileWindow?) -> TileWindow? {
        selectFn(engine, windowRight, window)
    }

    func up(_ engine: Engine, _ window: TileWindow?) -> TileWindow? {
        selectFn(engine, windowUp, window)
    }

    private func selectFn(_ engine: Engine,
                          _ direction: (TileWindow, [TileWindow]) -> [TileWindow],
                          _ window: TileWindow?) -> TileWindow? {
        let win = window ?? engine.focusWindow()
        guard let win else { return nil }
        let windowList = engine.activeWindowList()
        let array = direction(win, windowList)
        return array.first
    }
}

private func windowDown(_ focused: TileWindow, _ windows: [TileWindow]) -> [TileWindow] {
    let fr = focused.rect()
    return windows
        .filter { !$0.axWindow.isMinimized() && $0.rect().y > fr.y }
        .sorted { downwardDistance($0.rect(), fr) < downwardDistance($1.rect(), fr) }
}

private func windowLeft(_ focused: TileWindow, _ windows: [TileWindow]) -> [TileWindow] {
    let fr = focused.rect()
    return windows
        .filter { !$0.axWindow.isMinimized() && $0.rect().x < fr.x }
        .sorted { leftwardDistance($0.rect(), fr) < leftwardDistance($1.rect(), fr) }
}

private func windowRight(_ focused: TileWindow, _ windows: [TileWindow]) -> [TileWindow] {
    let fr = focused.rect()
    return windows
        .filter { !$0.axWindow.isMinimized() && $0.rect().x > fr.x }
        .sorted { rightwardDistance($0.rect(), fr) < rightwardDistance($1.rect(), fr) }
}

private func windowUp(_ focused: TileWindow, _ windows: [TileWindow]) -> [TileWindow] {
    let fr = focused.rect()
    return windows
        .filter { !$0.axWindow.isMinimized() && $0.rect().y < fr.y }
        .sorted { upwardDistance($0.rect(), fr) < upwardDistance($1.rect(), fr) }
}

// MARK: - Tiler

final class Tiler {
    var window: Entity? = nil
    var moving: Bool = false
    var resizingWindow: Bool = false
    private var swapWindow: Entity? = nil

    // MARK: - Toggle orientation

    func toggleOrientation(_ engine: Engine) {
        guard let window = engine.focusWindow(), let autoTiler = engine.autoTiler else { return }
        autoTiler.toggleOrientation(engine, window)
    }

    // MARK: - Toggle stacking

    func toggleStacking(_ engine: Engine) {
        engine.autoTiler?.toggleStacking(engine)
    }

    // MARK: - Move

    func moveLeft(_ engine: Engine, _ win: Entity? = nil) {
        move(engine, win ?? window, -1, 0, 0, 0, .left) {
            moveWindowOrMonitor(engine, engine.focusSelector.left, .left)
        }
    }

    func moveDown(_ engine: Engine, _ win: Entity? = nil) {
        move(engine, win ?? window, 0, 1, 0, 0, .down) {
            moveWindowOrMonitor(engine, engine.focusSelector.down, .down)
        }
    }

    func moveUp(_ engine: Engine, _ win: Entity? = nil) {
        move(engine, win ?? window, 0, -1, 0, 0, .up) {
            moveWindowOrMonitor(engine, engine.focusSelector.up, .up)
        }
    }

    func moveRight(_ engine: Engine, _ win: Entity? = nil) {
        move(engine, win ?? window, 1, 0, 0, 0, .right) {
            moveWindowOrMonitor(engine, engine.focusSelector.right, .right)
        }
    }

    private func move(_ engine: Engine, _ windowEntity: Entity?,
                      _ x: Int, _ y: Int, _ w: Int, _ h: Int,
                      _ direction: Direction,
                      _ focus: () -> MoveTarget?) {
        guard let windowEntity else { return }
        guard let win = engine.windows.get(windowEntity) else { return }

        if let autoTiler = engine.autoTiler, win.isTilable(engine) {
            guard let focused = engine.focusWindow() else { return }

            let moveTo = focus()
            moving = true

            // Check if in stack
            if let stackInfo = autoTiler.findStack(focused.entity) {
                moveFromStack(engine, stackInfo, focused, direction)
                moving = false
                return
            }

            if let moveTo {
                switch moveTo {
                case .window(let target):
                    moveAuto(engine, focused, target, direction: direction, stackFromLeft: direction == .left)
                case .monitor(let monitorIdx):
                    focused.ignoreDetach = true
                    autoTiler.detachWindow(engine, focused.entity)
                    autoTiler.attachToWorkspace(engine, focused, (monitorIdx, engine.activeWorkspace()))
                }
            }
            moving = false
        }
    }

    // MARK: - Move from stack

    func moveFromStack(_ engine: Engine, _ info: (Fork, Node, Bool),
                       _ focused: TileWindow, _ direction: Direction,
                       forceDetach: Bool = false) {
        guard let autoTiler = engine.autoTiler else { return }

        let (fork, branch, isLeft) = info
        guard let data = branch.stackData else { return }

        if data.entities.count == 1 {
            autoTiler.toggleStacking(engine)
            return
        }

        if fork.isToplevel && fork.smartGapped {
            fork.smartGapped = false
            var rect = engine.monitorWorkArea(fork.monitor)
            rect.x += engine.gapOuter; rect.y += engine.gapOuter
            rect.width -= engine.gapOuter * 2; rect.height -= engine.gapOuter * 2
            fork.setArea(rect)
        }

        let forest = autoTiler.forest
        let fentity = focused.entity

        let detach = { (orient: Orientation, reverse: Bool) in
            focused.stack = nil

            if fork.right != nil {
                let left: Node, right: Node
                if reverse {
                    left = branch; right = .window(fentity)
                } else {
                    left = .window(fentity); right = branch
                }
                let newFork = self.unstackFromFork(engine, data, focused, fork, left, right, isLeft)
                (newFork ?? fork).setOrientation(orient)
            } else if reverse {
                fork.right = .window(fentity)
            } else {
                fork.right = fork.left
                fork.left = .window(fentity)
            }

            let modifier = fork
            modifier.setOrientation(orient)
            forest.onAttach(modifier.entity, fentity)
            autoTiler.tile(engine, fork, fork.area)
        }

        switch direction {
        case .left:
            if forceDetach {
                stackRemove(forest, data, fentity)
                detach(.horizontal, false)
            } else if !stackMoveLeft(engine, forest, data, fentity) {
                detach(.horizontal, false)
            }
            autoTiler.updateStack(engine: engine, data)

        case .right:
            if forceDetach {
                stackRemove(forest, data, fentity)
                detach(.horizontal, true)
            } else if !stackMoveRight(engine, forest, data, fentity) {
                detach(.horizontal, true)
            }
            autoTiler.updateStack(engine: engine, data)

        case .up:
            stackRemove(forest, data, fentity)
            detach(.vertical, false)

        case .down:
            stackRemove(forest, data, fentity)
            detach(.vertical, true)
        }
    }

    func moveAlongsideStack(_ engine: Engine, _ info: (Fork, Node, Bool),
                            _ focused: TileWindow, _ direction: Direction) {
        guard let autoTiler = engine.autoTiler else { return }
        let (fork, branch, isLeft) = info
        guard let data = branch.stackData else { return }

        let orient: Orientation
        let reverse: Bool

        switch direction {
        case .left:  orient = .horizontal; reverse = false
        case .right: orient = .horizontal; reverse = true
        case .up:    orient = .vertical;   reverse = false
        case .down:  orient = .vertical;   reverse = true
        }

        stackRemove(autoTiler.forest, data, focused.entity)
        autoTiler.detachWindow(engine, focused.entity)
        focused.stack = nil

        if fork.right != nil {
            let left: Node, right: Node
            if reverse {
                left = branch; right = .window(focused.entity)
            } else {
                left = .window(focused.entity); right = branch
            }
            let newFork = unstackFromFork(engine, data, focused, fork, left, right, isLeft)
            (newFork ?? fork).setOrientation(orient)
        } else if reverse {
            fork.right = .window(focused.entity)
        } else {
            fork.right = fork.left
            fork.left = .window(focused.entity)
        }

        fork.setOrientation(orient)
        autoTiler.forest.onAttach(fork.entity, focused.entity)
        autoTiler.tile(engine, fork, fork.area)
    }

    private func unstackFromFork(_ engine: Engine, _ stack: StackData,
                                  _ focused: TileWindow, _ fork: Fork,
                                  _ left: Node, _ right: Node,
                                  _ isLeft: Bool) -> Fork? {
        guard let autoTiler = engine.autoTiler else { return nil }

        let forest = autoTiler.forest
        let (newForkEntity, newFork) = forest.createFork(
            left: left, right: right, area: fork.area,
            workspace: fork.workspace, monitor: fork.monitor)

        if isLeft {
            fork.left = .fork(newForkEntity)
        } else {
            fork.right = .fork(newForkEntity)
        }

        forest.parents.insert(newForkEntity, fork.entity)
        forest.onAttach(newForkEntity, focused.entity)
        for e in stack.entities {
            forest.onAttach(newForkEntity, e)
        }

        return newFork
    }

    // MARK: - Move auto

    func moveAuto(_ engine: Engine, _ focused: TileWindow, _ moveTo: TileWindow,
                  direction: Direction, stackFromLeft: Bool = true) {
        guard let at = engine.autoTiler else { return }

        // Check if moving onto a stack
        if at.findStack(moveTo.entity) != nil {
            focused.ignoreDetach = true
            at.detachWindow(engine, focused.entity)
            at.attachToWindow(engine, moveTo, focused, .auto, stackFromLeft: stackFromLeft)
        } else {
            let parent = at.windowsAreSiblings(focused.entity, moveTo.entity)
            if let parent, let fork = at.forest.forks.get(parent), fork.right != nil {
                if case .stack = fork.left.kind {
                    // Already handled
                } else {
                    let temp = fork.right!
                    fork.right = fork.left
                    fork.left = temp
                    at.tile(engine, fork, fork.area)
                }
            } else {
                // Direction-aware placement (aligned with drag behavior)
                let orient: Orientation = (direction == .left || direction == .right) ? .horizontal : .vertical
                let swap = (direction == .left || direction == .up)
                let movement: MoveBy = .cursor(orientation: orient, swap: swap)
                focused.ignoreDetach = true
                at.detachWindow(engine, focused.entity)
                at.attachToWindow(engine, moveTo, focused, movement, stackFromLeft: stackFromLeft)
            }
        }
    }

    // MARK: - Resize

    func resize(_ engine: Engine, _ direction: Direction) {
        // Fall back to focused window when not in tiling mode
        guard let windowEntity = window ?? engine.focusWindow()?.entity else { return }
        resizingWindow = true

        if engine.autoTiler != nil,
           !engine.containsTag(windowEntity, Tags.floating.rawValue) {
            resizeAuto(engine, direction, windowEntity)
        }

        resizingWindow = false
    }

    private func resizeAuto(_ engine: Engine, _ direction: Direction, _ windowEntity: Entity? = nil) {
        guard let autoTiler = engine.autoTiler,
              let windowEntity = windowEntity ?? window else { return }
        guard let entity = autoTiler.attached.get(windowEntity),
              let fork = autoTiler.forest.forks.get(entity),
              let win = engine.windows.get(windowEntity) else { return }

        let before = win.rect()
        let grabOp = GrabOp(entity: windowEntity, rect: before)

        let hrow = 64
        let hcolumn = 64

        let mov1: Rect, mov2: Rect
        switch direction {
        case .left:
            mov1 = Rect(x: hrow, y: 0, width: -hrow, height: 0)
            mov2 = Rect(x: 0, y: 0, width: -hrow, height: 0)
        case .right:
            mov1 = Rect(x: 0, y: 0, width: hrow, height: 0)
            mov2 = Rect(x: -hrow, y: 0, width: hrow, height: 0)
        case .up:
            mov1 = Rect(x: 0, y: hcolumn, width: 0, height: -hcolumn)
            mov2 = Rect(x: 0, y: 0, width: 0, height: -hcolumn)
        case .down:
            mov1 = Rect(x: 0, y: 0, width: 0, height: hcolumn)
            mov2 = Rect(x: 0, y: -hcolumn, width: 0, height: hcolumn)
        }

        var crect = grabOp.rect.clone()

        let workspaceId = engine.workspaceId(win)
        guard let toplevel = autoTiler.forest.findToplevel(workspaceId),
              let topfork = autoTiler.forest.forks.get(toplevel) else { return }
        let toparea = topfork.area

        var currentGrab = grabOp

        for mov in [mov1, mov2] {
            crect.apply(mov)
            let before = crect.clone()
            crect.clamp(toparea)
            let d = before.diff(crect)
            crect.apply(Rect(x: 0, y: 0, width: -d.x, height: -d.y))

            if crect != currentGrab.rect {
                autoTiler.forest.resize(engine, forkEntity: entity, fork: fork,
                                        winEntity: windowEntity, movement: currentGrab.operation(crect),
                                        crect: crect)
                currentGrab = GrabOp(entity: windowEntity, rect: crect.clone())
            }
        }

        autoTiler.forest.arrange(engine, fork.workspace)
    }

    // MARK: - Swap

    func swap(_ engine: Engine, _ selector: TileWindow?) {
        guard let sel = selector else { return }
        engine.setOverlay(sel.rect())
        swapWindow = sel.entity
    }

    func swapLeft(_ engine: Engine) {
        let w = swapWindow.flatMap { engine.windows.get($0) }
        swap(engine, engine.focusSelector.left(engine, w))
    }

    func swapDown(_ engine: Engine) {
        let w = swapWindow.flatMap { engine.windows.get($0) }
        swap(engine, engine.focusSelector.down(engine, w))
    }

    func swapUp(_ engine: Engine) {
        let w = swapWindow.flatMap { engine.windows.get($0) }
        swap(engine, engine.focusSelector.up(engine, w))
    }

    func swapRight(_ engine: Engine) {
        let w = swapWindow.flatMap { engine.windows.get($0) }
        swap(engine, engine.focusSelector.right(engine, w))
    }

    // MARK: - Accept / Exit

    func accept(_ engine: Engine) {
        guard let windowEntity = window, let meta = engine.windows.get(windowEntity) else {
            exit(engine); return
        }

        var treeSwapped = false

        if let sw = swapWindow, let autoTiler = engine.autoTiler {
            treeSwapped = true
            autoTiler.attachSwap(engine, sw, windowEntity)
        }

        if !treeSwapped {
            meta.move(engine, engine.overlayRect)
        }

        swapWindow = nil
        exit(engine)
    }

    func exit(_ engine: Engine) {
        if window != nil {
            window = nil
            engine.hideOverlay()
        }
    }

    // MARK: - Enter

    func enter(_ engine: Engine) {
        guard window == nil else { return }
        guard let win = engine.focusWindow() else { return }

        self.window = win.entity

        if win.isMaximized() {
            // Unmaximize by restoring size
        }

        engine.setOverlay(win.rect())
        engine.showOverlay()
    }
}

// MARK: - Move target

enum MoveTarget {
    case window(TileWindow)
    case monitor(Int)
}

private func moveWindowOrMonitor(_ engine: Engine,
                                  _ method: (Engine, TileWindow?) -> TileWindow?,
                                  _ direction: Direction) -> MoveTarget? {
    let nextWindow = method(engine, nil)
    guard let focus = engine.focusWindow() else { return nextWindow.map { .window($0) } }

    let nextMonitor = locateMonitor(engine, focus, direction)
    guard let nextWindow else { return nextMonitor.map { .monitor($0) } }

    guard let nextMonitor else { return .window(nextWindow) }

    let focusMonitor = focus.monitorIndex()
    if focusMonitor == nextWindow.monitorIndex() { return .window(nextWindow) }

    let monRect = engine.monitorWorkArea(nextMonitor)
    return monRect.contains(nextWindow.rect()) ? .window(nextWindow) : .monitor(nextMonitor)
}

func locateMonitor(_ engine: Engine, _ win: TileWindow, _ direction: Direction) -> Int? {
    let from = win.monitorIndex()
    let ref = engine.monitorWorkArea(from)
    let nMonitors = engine.monitorCount

    let origin: (Int, Int)
    let exclude: (Rect) -> Bool

    switch direction {
    case .up:
        origin = (ref.x + ref.width / 2, ref.y)
        exclude = { $0.y > ref.y }
    case .down:
        origin = (ref.x + ref.width / 2, ref.y + ref.height)
        exclude = { $0.y < ref.y }
    case .left:
        origin = (ref.x, ref.y + ref.height / 2)
        exclude = { $0.x > ref.x }
    case .right:
        origin = (ref.x + ref.width, ref.y + ref.height / 2)
        exclude = { $0.x < ref.x }
    }

    var best: (Int, Double)? = nil

    for mon in 0..<nMonitors {
        if mon == from { continue }
        let workArea = engine.monitorWorkArea(mon)
        if exclude(workArea) { continue }
        let weight = shortestSide(origin: origin, rect: workArea)
        if best == nil || weight < best!.1 {
            best = (mon, weight)
        }
    }

    return best?.0
}
