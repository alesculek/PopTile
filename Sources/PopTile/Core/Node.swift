// Node.swift — Tiling node ADT (Fork/Window/Stack)
// Direct port of pop-shell src/node.ts

import Foundation

/// Stack data stored inside a node
final class StackData {
    var idx: Int
    var entities: [Entity]
    var rect: Rect?

    init(idx: Int, entities: [Entity], rect: Rect? = nil) {
        self.idx = idx
        self.entities = entities
        self.rect = rect
    }

    /// Move entity at `from` to position `to`, shifting others accordingly.
    func reorder(from: Int, to: Int) {
        guard from != to,
              from >= 0, from < entities.count,
              to >= 0, to < entities.count else { return }
        let entity = entities.remove(at: from)
        entities.insert(entity, at: to)
    }
}

/// A tiling node may refer to a fork, a window, or a stack
final class Node {
    enum Kind {
        case fork(Entity)
        case window(Entity)
        case stack(StackData)
    }

    var kind: Kind

    init(_ kind: Kind) {
        self.kind = kind
    }

    static func fork(_ entity: Entity) -> Node { Node(.fork(entity)) }
    static func window(_ entity: Entity) -> Node { Node(.window(entity)) }
    static func stacked(_ entity: Entity, _ idx: Int) -> Node {
        Node(.stack(StackData(idx: idx, entities: [entity])))
    }

    // MARK: - Query methods

    /// True if this node is a fork matching the given entity
    func isFork(_ entity: Entity) -> Bool {
        if case .fork(let e) = kind { return e == entity }
        return false
    }

    /// True if this node is a window matching the given entity
    func isWindow(_ entity: Entity) -> Bool {
        if case .window(let e) = kind { return e == entity }
        return false
    }

    /// True if this entity exists as a child of this stack
    func isInStack(_ entity: Entity) -> Bool {
        if case .stack(let data) = kind {
            return data.entities.contains(entity)
        }
        return false
    }

    /// Get the fork entity if this is a fork node
    var forkEntity: Entity? {
        if case .fork(let e) = kind { return e }
        return nil
    }

    /// Get the window entity if this is a window node
    var windowEntity: Entity? {
        if case .window(let e) = kind { return e }
        return nil
    }

    /// Get the stack data if this is a stack node
    var stackData: StackData? {
        if case .stack(let data) = kind { return data }
        return nil
    }

    // MARK: - Measure

    func measure(tiler: Forest, engine: Engine, parent: Entity, area: Rect,
                 record: (Entity, Entity, Rect) -> Void) {
        switch kind {
        case .fork(let entity):
            if let fork = tiler.forks.get(entity) {
                fork.measure(tiler: tiler, engine: engine, area: area, record: record)
            }

        case .window(let entity):
            record(entity, parent, area.clone())

        case .stack(let data):
            let tabBarHeight = 28  // points — tab bar height (matches StackContainer.tabsHeight)
            var stackArea = area.clone()
            stackArea.y += tabBarHeight
            stackArea.height -= tabBarHeight
            data.rect = stackArea

            for entity in data.entities {
                record(entity, parent, stackArea)
            }

            if let autoTiler = engine.autoTiler {
                autoTiler.forest.stackUpdates.append((data, parent))
            }
        }
    }
}

// MARK: - Stack operations

func stackFind(_ data: StackData, _ entity: Entity) -> Int? {
    data.entities.firstIndex(of: entity)
}

func stackRemove(_ forest: Forest, _ data: StackData, _ entity: Entity) -> Int? {
    guard let container = forest.stacks.get(data.idx) else { return nil }
    let idx = container.removeTab(entity)
    if let idx {
        data.entities.remove(at: idx)
    }
    return idx
}

func stackMoveLeft(_ engine: Engine, _ forest: Forest, _ data: StackData, _ entity: Entity) -> Bool {
    guard let stack = forest.stacks.get(data.idx) else { return false }

    for (idx, cmp) in data.entities.enumerated() {
        if cmp == entity {
            if idx == 0 {
                // Remove from stack (detach)
                data.entities.remove(at: 0)
                stack.removeByPos(0)
                return false
            } else {
                // Swap left
                data.entities.swapAt(idx - 1, idx)
                stack.activeId -= 1
                engine.autoTiler?.updateStack(engine: engine, data)
                return true
            }
        }
    }
    return false
}

func stackMoveRight(_ engine: Engine, _ forest: Forest, _ data: StackData, _ entity: Entity) -> Bool {
    guard let stack = forest.stacks.get(data.idx) else { return false }

    let maxIdx = data.entities.count - 1
    for (idx, cmp) in data.entities.enumerated() {
        if cmp == entity {
            if idx == maxIdx {
                data.entities.remove(at: idx)
                stack.removeByPos(idx)
                return false
            } else {
                data.entities.swapAt(idx + 1, idx)
                stack.activeId += 1
                engine.autoTiler?.updateStack(engine: engine, data)
                return true
            }
        }
    }
    return false
}

func stackReplace(_ engine: Engine, _ data: StackData, _ window: TileWindow) {
    guard let autoTiler = engine.autoTiler else { return }
    guard let container = autoTiler.forest.stacks.get(data.idx) else { return }
    container.replace(window)
}
