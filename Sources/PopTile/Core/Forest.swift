// Forest.swift — Collection of fork trees
// Direct port of pop-shell src/forest.ts

import Foundation

/// A request to move a window into a new location
struct MoveRequest {
    let parent: Entity
    let rect: Rect
}

/// Movement origin for attach operations
enum MoveBy {
    case cursor(orientation: Orientation, swap: Bool)
    case keyboard(src: Rect)
    case auto
}

/// A collection of forks separated into trees.
/// Each display on each workspace has their own unique tree.
final class Forest: World {
    /// Top-level forks: key -> (entity, (monitor, workspace))
    var toplevel: [String: (Entity, (Int, Int))] = [:]

    /// Queued window position requests
    var requested: [Entity: MoveRequest] = [:]

    /// Stacks that need container redraws
    var stackUpdates: [(StackData, Entity)] = []

    /// Fork storage
    let forks: Storage<Fork> = Storage<Fork>()

    /// Child -> parent fork mapping
    let parents: Storage<Entity> = Storage<Entity>()

    /// String representations of entities (for map keys)
    let stringReps: Storage<String> = Storage<String>()

    /// Stack containers
    let stacks: Arena<StackContainer> = Arena<StackContainer>()

    /// Callbacks
    var onAttach: (Entity, Entity) -> Void = { _, _ in }
    var onDetach: (Entity) -> Void = { _ in }

    override init() {
        super.init()
    }

    // MARK: - Measure & Arrange

    func measure(_ engine: Engine, _ fork: Fork, _ area: Rect) {
        fork.measure(tiler: self, engine: engine, area: area, record: onRecord())
    }

    func tile(_ engine: Engine, _ fork: Fork, _ area: Rect, ignoreReset: Bool = true) {
        measure(engine, fork, area)
        arrange(engine, fork.workspace, ignoreReset: ignoreReset)
    }

    func arrange(_ engine: Engine, _ workspace: Int, ignoreReset: Bool = false) {
        for (entity, r) in requested {
            guard let window = engine.windows.get(entity) else { continue }
            moveWindow(engine: engine, window: window, rect: r.rect)
        }
        requested.removeAll()

        for (stack, _) in stackUpdates {
            engine.autoTiler?.updateStack(engine: engine, stack)
        }
        stackUpdates.removeAll()
    }

    // MARK: - Entity management

    override func createEntity() -> Entity {
        let entity = super.createEntity()
        stringReps.insert(entity, "\(entity)")
        return entity
    }

    override func deleteEntity(_ entity: Entity) {
        let fork = forks.remove(entity)
        if let fork, fork.isToplevel {
            if let id = stringReps.get(entity) {
                toplevel.removeValue(forKey: id)
            }
        }
        super.deleteEntity(entity)
    }

    // MARK: - Fork creation

    func createFork(left: Node, right: Node?, area: Rect,
                    workspace: Int, monitor: Int) -> (Entity, Fork) {
        let entity = createEntity()
        let orient: Orientation = area.width > area.height ? .horizontal : .vertical
        let fork = Fork(entity: entity, left: left, right: right, area: area,
                        workspace: workspace, monitor: monitor, orient: orient)
        forks.insert(entity, fork)
        return (entity, fork)
    }

    func createToplevel(window: Entity, area: Rect, id: (Int, Int)) -> (Entity, Fork) {
        let (entity, fork) = createFork(left: .window(window), right: nil,
                                         area: area, workspace: id.1, monitor: id.0)
        fork.setToplevel(self, entity, id)
        return (entity, fork)
    }

    // MARK: - Attach fork

    func attachFork(_ engine: Engine, _ fork: Fork, _ window: Entity, isLeft: Bool) {
        let node = Node.window(window)

        if isLeft {
            if fork.right != nil {
                let (newForkEntity, _) = createFork(
                    left: fork.left, right: fork.right,
                    area: fork.areaOfRight(engine),
                    workspace: fork.workspace, monitor: fork.monitor)
                fork.right = .fork(newForkEntity)
                parents.insert(newForkEntity, fork.entity)
                onAttach(newForkEntity, window)
            } else {
                onAttach(fork.entity, window)
                fork.right = fork.left
            }
            fork.left = node
        } else {
            if fork.right != nil {
                let (newForkEntity, _) = createFork(
                    left: fork.left, right: fork.right,
                    area: fork.areaOfLeft(engine),
                    workspace: fork.workspace, monitor: fork.monitor)
                fork.left = .fork(newForkEntity)
                parents.insert(newForkEntity, fork.entity)
                onAttach(newForkEntity, window)
            } else {
                onAttach(fork.entity, window)
            }
            fork.right = node
        }

        onAttach(fork.entity, window)
    }

    // MARK: - Attach stack

    func attachStack(_ engine: Engine, _ stack: StackData, _ fork: Fork,
                     _ newEntity: Entity, stackFromLeft: Bool) -> (Entity, Fork)? {
        guard let container = stacks.get(stack.idx) else { return nil }
        guard let window = engine.windows.get(newEntity) else { return nil }

        window.stack = stack.idx

        if stackFromLeft {
            stack.entities.append(newEntity)
        } else {
            stack.entities.insert(newEntity, at: 0)
        }

        onAttach(fork.entity, newEntity)
        engine.autoTiler?.updateStack(engine: engine, stack)

        if window.axWindow.isFocused() {
            container.activate(newEntity)
        }

        return (fork.entity, fork)
    }

    // MARK: - Attach window

    func attachWindow(_ engine: Engine, ontoEntity: Entity, newEntity: Entity,
                      placeBy: MoveBy, stackFromLeft: Bool) -> (Entity, Fork)? {

        func placeByKeyboard(_ fork: Fork, src: Rect, left: Rect, right: Rect) {
            let from = (src.x + src.width / 2, src.y + src.height / 2)
            let lside = shortestSide(origin: from, rect: left)
            let rside = shortestSide(origin: from, rect: right)
            if lside < rside { fork.swapBranches() }
        }

        func place(_ placeBy: MoveBy, _ fork: Fork, _ left: Rect, _ right: Rect) {
            switch placeBy {
            case .cursor(let orientation, let swap):
                fork.setOrientation(orientation)
                if swap { fork.swapBranches() }
            case .keyboard(let src):
                placeByKeyboard(fork, src: src, left: left, right: right)
            case .auto:
                break
            }
        }

        func areaOfHalves(_ fork: Fork) -> (Rect, Rect) {
            let a = fork.area
            if fork.isHorizontal() {
                return (Rect(x: a.x, y: a.y, width: a.width / 2, height: a.height),
                        Rect(x: a.x + a.width / 2, y: a.y, width: a.width / 2, height: a.height))
            } else {
                return (Rect(x: a.x, y: a.y, width: a.width, height: a.height / 2),
                        Rect(x: a.x, y: a.y + a.height / 2, width: a.width, height: a.height / 2))
            }
        }

        let rightNode = Node.window(newEntity)

        for (entity, fork) in forks.iter() {
            // Check left branch
            if fork.left.isWindow(ontoEntity) {
                if fork.right != nil {
                    // Fork and place on left
                    let area = fork.areaOfLeft(engine)
                    let (forkEntity, newFork) = createFork(
                        left: fork.left, right: rightNode, area: area,
                        workspace: fork.workspace, monitor: fork.monitor)
                    fork.left = .fork(forkEntity)
                    parents.insert(forkEntity, entity)
                    let (l, r) = areaOfHalves(newFork)
                    place(placeBy, newFork, l, r)
                    onAttach(forkEntity, ontoEntity)
                    onAttach(forkEntity, newEntity)
                    return (entity, fork)
                } else {
                    fork.right = rightNode
                    fork.setRatio(fork.length() / 2)
                    if case .keyboard(let src) = placeBy {
                        let (l, r) = areaOfHalves(fork)
                        placeByKeyboard(fork, src: src, left: l, right: r)
                    }
                    onAttach(entity, newEntity)
                    return (entity, fork)
                }
            } else if fork.left.isInStack(ontoEntity) {
                let stack = fork.left.stackData!
                return attachStack(engine, stack, fork, newEntity, stackFromLeft: stackFromLeft)
            }

            // Check right branch
            if let rightBranch = fork.right {
                if rightBranch.isWindow(ontoEntity) {
                    let area = fork.areaOfRight(engine)
                    let (forkEntity, newFork) = createFork(
                        left: rightBranch, right: rightNode, area: area,
                        workspace: fork.workspace, monitor: fork.monitor)
                    fork.right = .fork(forkEntity)
                    parents.insert(forkEntity, entity)
                    let (l, r) = areaOfHalves(newFork)
                    place(placeBy, newFork, l, r)
                    onAttach(forkEntity, ontoEntity)
                    onAttach(forkEntity, newEntity)
                    return (entity, fork)
                } else if rightBranch.isInStack(ontoEntity) {
                    let stack = rightBranch.stackData!
                    return attachStack(engine, stack, fork, newEntity, stackFromLeft: stackFromLeft)
                }
            }
        }

        return nil
    }

    // MARK: - Detach

    func detach(_ engine: Engine, forkEntity: Entity, window: Entity) -> (Entity, Fork)? {
        guard let fork = forks.get(forkEntity) else { return nil }

        var reflowFork: (Entity, Fork)? = nil
        var stackDetach = false
        let parent = parents.get(forkEntity)

        if fork.left.isWindow(window) {
            if let parent, let right = fork.right {
                if let pfork = reassignChildToParent(forkEntity, parent, right) {
                    reflowFork = (parent, pfork)
                }
            } else if let right = fork.right {
                reflowFork = (forkEntity, fork)
                switch right.kind {
                case .fork(let childEntity):
                    reassignChildrenToParent(forkEntity, childEntity, fork)
                default:
                    fork.left = right
                    fork.right = nil
                }
            } else {
                deleteEntity(forkEntity)
            }
        } else if fork.left.isInStack(window) {
            reflowFork = (forkEntity, fork)
            stackDetach = true
            removeFromStack(engine, fork.left.stackData!, window) {
                if let right = fork.right {
                    fork.left = right
                    fork.right = nil
                    if let parent {
                        if let pfork = self.reassignChildToParent(forkEntity, parent, fork.left) {
                            reflowFork = (parent, pfork)
                        }
                    }
                } else {
                    self.deleteEntity(fork.entity)
                }
            }
            // Auto-unstack: if only 1 window remains in the stack, convert back to plain window
            if let data = fork.left.stackData, data.entities.count == 1 {
                let remaining = data.entities[0]
                stacks.remove(data.idx)?.destroy()
                engine.windows.with(remaining) { w in (w as TileWindow).stack = nil }
                fork.left = .window(remaining)
            }
        } else if let rightBranch = fork.right {
            if rightBranch.isWindow(window) {
                if let parent {
                    if let pfork = reassignChildToParent(forkEntity, parent, fork.left) {
                        reflowFork = (parent, pfork)
                    }
                } else {
                    reflowFork = (forkEntity, fork)
                    switch fork.left.kind {
                    case .fork(let childEntity):
                        reassignChildrenToParent(forkEntity, childEntity, fork)
                    default:
                        fork.right = nil
                    }
                }
            } else if rightBranch.isInStack(window) {
                reflowFork = (forkEntity, fork)
                stackDetach = true
                removeFromStack(engine, rightBranch.stackData!, window) {
                    fork.right = nil
                    self.reassignToParent(fork, fork.left)
                }
                // Auto-unstack: if only 1 window remains in the stack, convert back to plain window
                if let right = fork.right, let data = right.stackData, data.entities.count == 1 {
                    let remaining = data.entities[0]
                    stacks.remove(data.idx)?.destroy()
                    engine.windows.with(remaining) { w in (w as TileWindow).stack = nil }
                    fork.right = .window(remaining)
                }
            }
        }

        if stackDetach {
            engine.windows.with(window) { w in
                let tw = w as TileWindow
                tw.stack = nil
            }
        }

        onDetach(window)

        if let rf = reflowFork, !stackDetach {
            rf.1.rebalanceOrientation()
        }

        return reflowFork
    }

    // MARK: - Iterator

    func iterFork(_ entity: Entity) -> [Node] {
        var result: [Node] = []
        var forkQueue: [Fork] = []

        if let fork = forks.get(entity) {
            forkQueue.append(fork)
        }

        while let fork = forkQueue.popLast() {
            if case .fork(let e) = fork.left.kind, let childFork = forks.get(e) {
                forkQueue.append(childFork)
            }
            result.append(fork.left)

            if let right = fork.right {
                if case .fork(let e) = right.kind, let childFork = forks.get(e) {
                    forkQueue.append(childFork)
                }
                result.append(right)
            }
        }

        return result
    }

    // MARK: - Find

    func findToplevel(_ id: (Int, Int)) -> Entity? {
        for (_, fork) in forks.iter() {
            if !fork.isToplevel { continue }
            if fork.monitor == id.0 && fork.workspace == id.1 {
                return fork.entity
            }
        }
        return nil
    }

    func largestWindowOn(_ engine: Engine, _ entity: Entity) -> TileWindow? {
        var largestWindow: TileWindow? = nil
        var largestSize = 0

        for node in iterFork(entity) {
            let checkEntity: Entity?
            switch node.kind {
            case .window(let e): checkEntity = e
            case .stack(let data): checkEntity = data.entities.first
            default: checkEntity = nil
            }

            if let e = checkEntity, let window = engine.windows.get(e), window.isTilable(engine) {
                let r = window.rect()
                let size = r.width * r.height
                if size > largestSize {
                    largestSize = size
                    largestWindow = window
                }
            }
        }

        return largestWindow
    }

    // MARK: - Record

    func onRecord() -> (Entity, Entity, Rect) -> Void {
        return { [weak self] e, p, a in self?.record(e, p, a) }
    }

    private func record(_ entity: Entity, _ parent: Entity, _ rect: Rect) {
        requested[entity] = MoveRequest(parent: parent, rect: rect)
    }

    // MARK: - Resize

    func resize(_ engine: Engine, forkEntity: Entity, fork: Fork,
                winEntity: Entity, movement: Movement, crect: Rect) {
        let isLeft = fork.left.isWindow(winEntity) || fork.left.isInStack(winEntity)

        if movement.contains(.shrink) {
            shrinkSibling(engine, forkEntity, fork, isLeft, movement, crect)
        } else {
            growSibling(engine, forkEntity, fork, isLeft, movement, crect)
        }
    }

    private func growSibling(_ engine: Engine, _ forkE: Entity, _ forkC: Fork,
                             _ isLeft: Bool, _ movement: Movement, _ crect: Rect) {
        let resizeFork = { self.resizeFork_(engine, forkE, crect, movement, false) }

        if forkC.isHorizontal() {
            if !movement.isDisjoint(with: [.down, .up]) {
                resizeFork()
            } else if isLeft {
                if movement.contains(.right) {
                    readjustForkRatioByLeft(engine, crect.width, forkC)
                } else {
                    resizeFork()
                }
            } else if movement.contains(.right) {
                resizeFork()
            } else {
                readjustForkRatioByRight(engine, crect.width, forkC, forkC.area.width)
            }
        } else {
            if !movement.isDisjoint(with: [.left, .right]) {
                resizeFork()
            } else if isLeft {
                if movement.contains(.down) {
                    readjustForkRatioByLeft(engine, crect.height, forkC)
                } else {
                    resizeFork()
                }
            } else if movement.contains(.down) {
                resizeFork()
            } else {
                readjustForkRatioByRight(engine, crect.height, forkC, forkC.area.height)
            }
        }
    }

    private func shrinkSibling(_ engine: Engine, _ forkE: Entity, _ forkC: Fork,
                               _ isLeft: Bool, _ movement: Movement, _ crect: Rect) {
        let resizeFork = { self.resizeFork_(engine, forkE, crect, movement, true) }

        if forkC.isHorizontal() {
            if !movement.isDisjoint(with: [.down, .up]) {
                resizeFork()
            } else if isLeft {
                if movement.contains(.left) {
                    readjustForkRatioByLeft(engine, crect.width, forkC)
                } else {
                    resizeFork()
                }
            } else if movement.contains(.left) {
                resizeFork()
            } else {
                readjustForkRatioByRight(engine, crect.width, forkC, forkC.area.width)
            }
        } else {
            if !movement.isDisjoint(with: [.left, .right]) {
                resizeFork()
            } else if isLeft {
                if movement.contains(.up) {
                    readjustForkRatioByLeft(engine, crect.height, forkC)
                } else {
                    resizeFork()
                }
            } else if movement.contains(.up) {
                resizeFork()
            } else {
                readjustForkRatioByRight(engine, crect.height, forkC, forkC.area.height)
            }
        }
    }

    private func readjustForkRatioByLeft(_ engine: Engine, _ leftLength: Int, _ fork: Fork) {
        fork.setRatio(leftLength)
        fork.measure(tiler: self, engine: engine, area: fork.area, record: onRecord())
    }

    private func readjustForkRatioByRight(_ engine: Engine, _ rightLength: Int,
                                          _ fork: Fork, _ forkLength: Int) {
        readjustForkRatioByLeft(engine, forkLength - rightLength, fork)
    }

    private func resizeFork_(_ engine: Engine, _ childE: Entity, _ crect: Rect,
                              _ mov: Movement, _ shrunk: Bool) {
        var childE = childE
        var parent = parents.get(childE)

        guard let srcNode = forks.get(childE) else { return }

        if parent == nil {
            srcNode.measure(tiler: self, engine: engine, area: srcNode.area, record: onRecord())
            return
        }

        var child: Fork = srcNode
        var isLeft: Bool = false

        while parent != nil {
            guard let pFork = forks.get(parent!) else { break }
            child = pFork
            isLeft = child.left.isFork(childE)

            if child.area.contains(crect) {
                if mov.contains(.up) {
                    if shrunk {
                        if child.area.y + child.area.height > srcNode.area.y + srcNode.area.height { break }
                    } else if !child.isHorizontal() || !isLeft { break }
                } else if mov.contains(.down) {
                    if shrunk {
                        if child.area.y < srcNode.area.y { break }
                    } else if child.isHorizontal() || isLeft { break }
                } else if mov.contains(.left) {
                    if shrunk {
                        if child.area.x + child.area.width > srcNode.area.x + srcNode.area.width { break }
                    } else if !child.isHorizontal() || !isLeft { break }
                } else if mov.contains(.right) {
                    if shrunk {
                        if child.area.x < srcNode.area.x { break }
                    } else if !child.isHorizontal() || isLeft { break }
                }
            }

            childE = parent!
            parent = parents.get(childE)
        }

        let length: Int
        if child.isHorizontal() {
            length = isLeft ? crect.x + crect.width - child.area.x : crect.x - child.area.x
        } else {
            length = isLeft ? crect.y + crect.height - child.area.y : child.area.height - crect.height
        }

        child.setRatio(length)
        child.measure(tiler: self, engine: engine, area: child.area, record: onRecord())
    }

    // MARK: - Reassignment helpers

    private func reassignChildToParent(_ childEntity: Entity, _ parentEntity: Entity,
                                       _ branch: Node) -> Fork? {
        guard let parent = forks.get(parentEntity) else { return nil }

        if parent.left.isFork(childEntity) {
            parent.left = branch
        } else {
            parent.right = branch
        }

        reassignSibling(branch, parentEntity)
        deleteEntity(childEntity)
        return parent
    }

    func reassignToParent(_ child: Fork, _ reassign: Node) {
        guard let p = parents.get(child.entity), let pFork = forks.get(p) else { return }

        if pFork.left.isFork(child.entity) {
            pFork.left = reassign
        } else {
            pFork.right = reassign
        }

        switch reassign.kind {
        case .fork(let e):
            parents.insert(e, p)
        case .window(let e):
            onAttach(p, e)
        case .stack(let data):
            for e in data.entities { onAttach(p, e) }
        }

        deleteEntity(child.entity)
    }

    private func reassignSibling(_ sibling: Node, _ parent: Entity) {
        switch sibling.kind {
        case .fork(let e):
            parents.insert(e, parent)
        case .window(let e):
            onAttach(parent, e)
        case .stack(let data):
            for e in data.entities { onAttach(parent, e) }
        }
    }

    private func reassignChildrenToParent(_ parentEntity: Entity, _ childEntity: Entity,
                                          _ pFork: Fork) {
        guard let cFork = forks.get(childEntity) else { return }

        pFork.left = cFork.left
        pFork.right = cFork.right

        reassignSibling(pFork.left, parentEntity)
        if let right = pFork.right { reassignSibling(right, parentEntity) }

        deleteEntity(childEntity)
    }

    // MARK: - Stack helpers

    private func removeFromStack(_ engine: Engine, _ stack: StackData, _ window: Entity,
                                 _ onLast: () -> Void) {
        if stack.entities.count == 1 {
            stacks.remove(stack.idx)?.destroy()
            onLast()
        } else {
            if let s = stacks.get(stack.idx) {
                stackRemove(self, stack, window)
            }
        }
        engine.windows.with(window) { w in
            (w as TileWindow).stack = nil
        }
    }

    // MARK: - Connect callbacks

    func connectOnAttach(_ callback: @escaping (Entity, Entity) -> Void) {
        onAttach = callback
    }

    func connectOnDetach(_ callback: @escaping (Entity) -> Void) {
        onDetach = callback
    }
}

// MARK: - Window movement

private func moveWindow(engine: Engine, window: TileWindow, rect: Rect) {
    guard rect.width > 0 && rect.height > 0 else {
        log(" moveWindow SKIP \(window.title()) — invalid rect \(rect.width)x\(rect.height)")
        return
    }
    log(" moveWindow \(window.title()) → (\(rect.x),\(rect.y)) \(rect.width)x\(rect.height)")
    // Record expected position and time BEFORE moving so async AX notifications can be filtered
    window.expectedRect = rect
    window.lastTiledAt = CFAbsoluteTimeGetCurrent()
    let wasPerforming = engine.isPerformingTile
    engine.isPerformingTile = true
    window.move(engine, rect)
    engine.isPerformingTile = wasPerforming

    // If the window failed AX, detach it from the tree asynchronously
    if window.axFailed {
        log(" Window \(window.title()) failed AX — removing from tiling")
        DispatchQueue.main.async {
            engine.autoTiler?.detachWindow(engine, window.entity)
        }
    }
}
