// AutoTiler.swift — Auto-tiling orchestrator
// Direct port of pop-shell src/auto_tiler.ts

import Foundation

/// Tags for window state
enum Tags: Int {
    case floating = 1
    case tiled = 2
    case forceTile = 3
}

final class AutoTiler {
    var forest: Forest
    var attached: Storage<Entity>

    init(forest: Forest, attached: Storage<Entity>) {
        self.forest = forest
        self.attached = attached
    }

    // MARK: - Swap

    func attachSwap(_ engine: Engine, _ a: Entity, _ b: Entity) {
        guard let aEnt = attached.get(a), let bEnt = attached.get(b),
              var aWin = engine.windows.get(a), var bWin = engine.windows.get(b),
              let aFork = forest.forks.get(aEnt), let bFork = forest.forks.get(bEnt) else { return }

        let aStack = aWin.stack, bStack = bWin.stack

        if let aStackIdx = aWin.stack, let stack = forest.stacks.get(aStackIdx) {
            let active = stack.active
            if let w = engine.windows.get(active) {
                aWin = w
                stack.deactivate(aWin)
            }
        }

        if let bStackIdx = bWin.stack, let stack = forest.stacks.get(bStackIdx) {
            let active = stack.active
            if let w = engine.windows.get(active) {
                bWin = w
                stack.deactivate(bWin)
            }
        }

        let aFn = aFork.replaceWindow(engine, aWin, bWin)
        forest.onAttach(aEnt, b)

        let bFn = bFork.replaceWindow(engine, bWin, aWin)
        forest.onAttach(bEnt, a)

        aFn?()
        bFn?()

        aWin.stack = bStack
        bWin.stack = aStack

        tile(engine, aFork, aFork.area)
        tile(engine, bFork, bFork.area)
    }

    // MARK: - Toplevel updates

    func updateToplevel(_ engine: Engine, _ fork: Fork, _ monitor: Int, smartGaps: Bool) {
        var rect = engine.monitorWorkArea(monitor)

        fork.smartGapped = smartGaps && fork.right == nil

        if !fork.smartGapped {
            rect.x += engine.gapOuter
            rect.y += engine.gapOuter
            rect.width -= engine.gapOuter * 2
            rect.height -= engine.gapOuter * 2
        }

        if case .window(let e) = fork.left.kind, let win = engine.windows.get(e) {
            win.smartGapped = fork.smartGapped
        }

        fork.area = fork.setArea(rect.clone())
        let forkLen = fork.length()
        fork.lengthLeft = forkLen > 0 ? Int((fork.prevRatio * Double(forkLen)).rounded()) : 0
        tile(engine, fork, fork.area)
    }

    // MARK: - Attach operations

    func attachToMonitor(_ engine: Engine, _ win: TileWindow,
                         _ workspaceId: (Int, Int), smartGaps: Bool) {
        var rect = engine.monitorWorkArea(workspaceId.0)

        if !smartGaps {
            rect.x += engine.gapOuter
            rect.y += engine.gapOuter
            rect.width -= engine.gapOuter * 2
            rect.height -= engine.gapOuter * 2
        }

        let (entity, fork) = forest.createToplevel(window: win.entity, area: rect.clone(), id: workspaceId)
        forest.onAttach(entity, win.entity)
        fork.smartGapped = smartGaps
        win.smartGapped = smartGaps

        tile(engine, fork, rect)
    }

    func attachToWindow(_ engine: Engine, _ attachee: TileWindow, _ attacher: TileWindow,
                        _ moveBy: MoveBy, stackFromLeft: Bool = true) -> Bool {
        // Check monitor mapping exists before modifying the tree
        guard engine.monitors.contains(attachee.entity) else { return false }

        guard let attached = forest.attachWindow(engine, ontoEntity: attachee.entity,
                                                  newEntity: attacher.entity,
                                                  placeBy: moveBy, stackFromLeft: stackFromLeft) else {
            return false
        }

        let (_, fork) = attached
        if fork.isToplevel && fork.smartGapped && fork.right != nil {
            fork.smartGapped = false
            var rect = engine.monitorWorkArea(fork.monitor)
            rect.x += engine.gapOuter
            rect.y += engine.gapOuter
            rect.width -= engine.gapOuter * 2
            rect.height -= engine.gapOuter * 2
            fork.setArea(rect)
        }
        tile(engine, fork, fork.area.clone())
        return true
    }

    func attachToWorkspace(_ engine: Engine, _ win: TileWindow, _ id: (Int, Int)) {
        let toplevel = forest.findToplevel(id)

        if let toplevel {
            let onto = forest.largestWindowOn(engine, toplevel)
            if let onto {
                if attachToWindow(engine, onto, win, .auto) {
                    return
                }
            }
        }

        attachToMonitor(engine, win, id, smartGaps: engine.settings.smartGaps)
    }

    // MARK: - Auto tile

    func autoTile(_ engine: Engine, _ win: TileWindow, ignoreFocus: Bool = false) {
        let mode = fetchMode(engine, win, ignoreFocus: ignoreFocus)
        detachWindow(engine, win.entity)

        if let onto = mode {
            attachToWindow(engine, onto, win, .auto)
        } else {
            attachToWorkspace(engine, win, engine.workspaceId(win))
        }
    }

    // MARK: - Detach

    func detachWindow(_ engine: Engine, _ win: Entity) {
        attached.takeWith(win) { prevFork in
            let reflowFork = self.forest.detach(engine, forkEntity: prevFork, window: win)

            if let (forkEntity, fork) = reflowFork {
                // Walk up to the toplevel fork and retile the whole tree
                // to ensure remaining windows fill the entire monitor area
                var topEntity = forkEntity
                var topFork = fork
                while let parent = self.forest.parents.get(topEntity),
                      let parentFork = self.forest.forks.get(parent) {
                    topEntity = parent
                    topFork = parentFork
                }

                if topFork.isToplevel && engine.settings.smartGaps && topFork.right == nil {
                    let rect = engine.monitorWorkArea(topFork.monitor)
                    topFork.setArea(rect)
                    topFork.smartGapped = true
                } else if topFork.isToplevel && topFork.smartGapped && topFork.right != nil {
                    topFork.smartGapped = false
                    var rect = engine.monitorWorkArea(topFork.monitor)
                    rect.x += engine.gapOuter
                    rect.y += engine.gapOuter
                    rect.width -= engine.gapOuter * 2
                    rect.height -= engine.gapOuter * 2
                    topFork.setArea(rect)
                }

                self.tile(engine, topFork, topFork.area)
            }

            engine.windows.with(win) { w in
                (w as TileWindow).ignoreDetach = false
            }
        }
    }

    // MARK: - Tile

    func tile(_ engine: Engine, _ fork: Fork, _ area: Rect) {
        forest.tile(engine, fork, area)
    }

    // MARK: - Toggle floating

    func toggleFloating(_ engine: Engine) {
        guard let focused = engine.focusWindow() else { return }

        let isFloatException = false // TODO: check float exceptions

        if isFloatException {
            if engine.containsTag(focused.entity, Tags.forceTile.rawValue) {
                engine.deleteTag(focused.entity, Tags.forceTile.rawValue)
                if let forkEntity = attached.get(focused.entity) {
                    detachWindow(engine, focused.entity)
                }
            } else {
                engine.addTag(focused.entity, Tags.forceTile.rawValue)
                autoTile(engine, focused, ignoreFocus: false)
            }
        } else {
            if engine.containsTag(focused.entity, Tags.floating.rawValue) {
                engine.deleteTag(focused.entity, Tags.floating.rawValue)
                autoTile(engine, focused, ignoreFocus: false)
            } else {
                if let _ = attached.get(focused.entity) {
                    detachWindow(engine, focused.entity)
                    engine.addTag(focused.entity, Tags.floating.rawValue)
                }
            }
        }
    }

    // MARK: - Toggle orientation

    func toggleOrientation(_ engine: Engine, _ window: TileWindow) {
        if window.isMaximized() { return }

        guard let forkEntity = attached.get(window.entity),
              let fork = forest.forks.get(forkEntity) else { return }

        guard fork.right != nil else { return }

        fork.toggleOrientation()
        forest.measure(engine, fork, fork.area)

        for node in forest.iterFork(forkEntity) {
            if case .fork(let childEntity) = node.kind, let childFork = forest.forks.get(childEntity) {
                childFork.rebalanceOrientation()
                forest.measure(engine, childFork, childFork.area)
            }
        }

        forest.arrange(engine, fork.workspace, ignoreReset: true)
    }

    // MARK: - Stacking

    func toggleStacking(_ engine: Engine, window: TileWindow? = nil) {
        guard let focused = window ?? engine.focusWindow() else { return }

        if engine.containsTag(focused.entity, Tags.floating.rawValue) {
            engine.deleteTag(focused.entity, Tags.floating.rawValue)
            autoTile(engine, focused, ignoreFocus: false)
        }

        guard let forkEntity = attached.get(focused.entity),
              let fork = forest.forks.get(forkEntity) else { return }

        unstack(engine, fork, focused, toggled: true)
    }

    func unstack(_ engine: Engine, _ fork: Fork, _ win: TileWindow, toggled: Bool = false) {
        let stackToggle = { (fork: Fork, branch: Node) -> Node? in
            guard let data = branch.stackData else { return nil }
            if data.entities.count == 1 {
                win.stack = nil
                self.forest.stacks.remove(data.idx)?.destroy()
                fork.measure(tiler: self.forest, engine: engine, area: fork.area,
                           record: self.forest.onRecord())
                return .window(win.entity)
            }
            return nil
        }

        if toggled && fork.left.isWindow(win.entity) {
            // Convert to stack
            let stackIdx = forest.stacks.insert(
                StackContainer(engine: engine, active: win.entity,
                              workspace: fork.workspace, monitor: fork.monitor))
            win.stack = stackIdx
            fork.left = .stacked(win.entity, stackIdx)
            fork.measure(tiler: forest, engine: engine, area: fork.area, record: forest.onRecord())
        } else if fork.left.isInStack(win.entity) {
            if let node = stackToggle(fork, fork.left) {
                fork.left = node
                if fork.right == nil {
                    forest.reassignToParent(fork, node)
                }
            }
        } else if toggled, let right = fork.right, right.isWindow(win.entity) {
            let stackIdx = forest.stacks.insert(
                StackContainer(engine: engine, active: win.entity,
                              workspace: fork.workspace, monitor: fork.monitor))
            win.stack = stackIdx
            fork.right = .stacked(win.entity, stackIdx)
            fork.measure(tiler: forest, engine: engine, area: fork.area, record: forest.onRecord())
        } else if let right = fork.right, right.isInStack(win.entity) {
            if let node = stackToggle(fork, right) {
                fork.right = node
            }
        }

        tile(engine, fork, fork.area)
    }

    func createStack(_ engine: Engine, _ window: TileWindow) {
        guard let entity = attached.get(window.entity),
              let fork = forest.forks.get(entity) else { return }

        if fork.left.isWindow(window.entity) {
            stackLeft(engine, fork, window)
        } else if let right = fork.right, right.isWindow(window.entity) {
            stackRight(engine, fork, window)
        }
    }

    func stackLeft(_ engine: Engine, _ fork: Fork, _ window: TileWindow) {
        let stackIdx = forest.stacks.insert(
            StackContainer(engine: engine, active: window.entity,
                          workspace: fork.workspace, monitor: fork.monitor))
        window.stack = stackIdx
        fork.left = .stacked(window.entity, stackIdx)
        fork.measure(tiler: forest, engine: engine, area: fork.area, record: forest.onRecord())
    }

    func stackRight(_ engine: Engine, _ fork: Fork, _ window: TileWindow) {
        let stackIdx = forest.stacks.insert(
            StackContainer(engine: engine, active: window.entity,
                          workspace: fork.workspace, monitor: fork.monitor))
        window.stack = stackIdx
        fork.right = .stacked(window.entity, stackIdx)
        fork.measure(tiler: forest, engine: engine, area: fork.area, record: forest.onRecord())
    }

    func updateStack(engine: Engine, _ stack: StackData) {
        guard let rect = stack.rect, let container = forest.stacks.get(stack.idx) else { return }

        container.clear()
        container.stackData = stack

        for entity in stack.entities {
            if let window = engine.windows.get(entity) {
                window.stack = stack.idx
                container.add(window)
            }
        }

        container.updatePositions(rect)
        container.autoActivate()
    }

    // MARK: - Find stack

    func findStack(_ entity: Entity) -> (Fork, Node, Bool)? {
        guard let att = attached.get(entity), let fork = forest.forks.get(att) else { return nil }

        if fork.left.isInStack(entity) { return (fork, fork.left, true) }
        if let right = fork.right, right.isInStack(entity) { return (fork, right, false) }
        return nil
    }

    func getParentFork(_ window: Entity) -> Fork? {
        guard let entity = attached.get(window) else { return nil }
        return forest.forks.get(entity)
    }

    func windowsAreSiblings(_ a: Entity, _ b: Entity) -> Entity? {
        guard let aParent = attached.get(a), let bParent = attached.get(b),
              aParent == bParent else { return nil }
        return aParent
    }

    func largestOnWorkspace(_ engine: Engine, monitor: Int, workspace: Int) -> TileWindow? {
        let toplevel = forest.findToplevel((monitor, workspace))
        if let toplevel { return forest.largestWindowOn(engine, toplevel) }
        return nil
    }

    // MARK: - Private

    private func fetchMode(_ engine: Engine, _ win: TileWindow,
                          ignoreFocus: Bool = false) -> TileWindow? {
        if ignoreFocus { return nil }

        guard let prev = engine.previouslyFocused(win),
              let onto = engine.windows.get(prev) else { return nil }

        if onto.entity == win.entity { return nil }
        if !onto.isTilable(engine) { return nil }
        if onto.axWindow.isMinimized() { return nil }
        if !attached.contains(onto.entity) { return nil }

        let ontoMonitor = onto.monitorIndex()
        let winMonitor = win.monitorIndex()

        return ontoMonitor == winMonitor ? onto : nil
    }

    // MARK: - Destroy

    func destroy(_ engine: Engine) {
        for (_, stack) in forest.stacks.values().enumerated() {
            stack.destroy()
        }
        for window in engine.windows.values() {
            (window as TileWindow).stack = nil
        }
        forest.stacks.truncate(0)
    }
}
