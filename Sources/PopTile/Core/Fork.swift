// Fork.swift — Binary tiling fork
// Direct port of pop-shell src/fork.ts

import Foundation

/// A tiling fork contains two children nodes.
/// These nodes may either be windows, sub-forks, or stacks.
final class Fork {
    var left: Node
    var right: Node?
    var area: Rect
    var entity: Entity
    var workspace: Int
    var monitor: Int
    var lengthLeft: Int
    var prevLengthLeft: Int
    var prevRatio: Double = 0.5
    var minimumRatio: Double = 0.1
    var orientation: Orientation = .horizontal
    var orientationChanged: Bool = false
    var isToplevel: Bool = false
    var smartGapped: Bool = false
    private var nToggled: Int = 0

    init(entity: Entity, left: Node, right: Node?, area: Rect,
         workspace: Int, monitor: Int, orient: Orientation) {
        self.entity = entity
        self.left = left
        self.right = right
        self.area = area
        self.workspace = workspace
        self.monitor = monitor
        self.orientation = orient
        self.lengthLeft = orient == .horizontal ? area.width / 2 : area.height / 2
        self.prevLengthLeft = self.lengthLeft
    }

    // MARK: - Area calculations

    func areaOfLeft(_ engine: Engine) -> Rect {
        if isHorizontal() {
            return Rect(x: area.x, y: area.y,
                        width: lengthLeft - engine.gapInnerHalf, height: area.height)
        } else {
            return Rect(x: area.x, y: area.y,
                        width: area.width, height: lengthLeft - engine.gapInnerHalf)
        }
    }

    func areaOfRight(_ engine: Engine) -> Rect {
        if isHorizontal() {
            let x = area.x + lengthLeft + engine.gapInnerHalf
            let w = area.width - lengthLeft - engine.gapInnerHalf
            return Rect(x: x, y: area.y, width: max(1, w), height: area.height)
        } else {
            let y = area.y + lengthLeft + engine.gapInnerHalf
            let h = area.height - lengthLeft - engine.gapInnerHalf
            return Rect(x: area.x, y: y, width: area.width, height: max(1, h))
        }
    }

    func depth() -> Int {
        isHorizontal() ? area.height : area.width
    }

    func isHorizontal() -> Bool {
        orientation == .horizontal
    }

    func length() -> Int {
        isHorizontal() ? area.width : area.height
    }

    func findBranch(_ entity: Entity) -> Node? {
        if left.isWindow(entity) || left.isInStack(entity) { return left }
        if let right, right.isWindow(entity) || right.isInStack(entity) { return right }
        return nil
    }

    // MARK: - Ratio

    @discardableResult
    func setRatio(_ leftLength: Int) -> Fork {
        let forkLen = isHorizontal() ? area.width : area.height
        guard forkLen > 0 else { return self }
        let minLen = min(256, forkLen / 4)
        let clamped = max(minLen, min(forkLen - minLen, leftLength))
        prevLengthLeft = clamped
        lengthLeft = clamped
        return self
    }

    @discardableResult
    func setArea(_ area: Rect) -> Rect {
        self.area = area
        return self.area
    }

    func setToplevel(_ tiler: Forest, _ entity: Entity, _ id: (Int, Int)) {
        isToplevel = true
        let key = "\(entity)"
        tiler.toplevel[key] = (entity, id)
    }

    // MARK: - Orientation

    func setOrientation(_ o: Orientation) {
        if o != orientation {
            orientation = o
            orientationChanged = true
        }
    }

    func toggleOrientation() {
        orientation = orientation == .horizontal ? .vertical : .horizontal
        orientationChanged = true
        if nToggled == 1 {
            swapBranches()
            nToggled = 0
        } else {
            nToggled += 1
        }
    }

    func rebalanceOrientation() {
        setOrientation(area.height > area.width ? .vertical : .horizontal)
    }

    func swapBranches() {
        if let r = right {
            let tmp = left
            left = r
            right = tmp
        }
    }

    // MARK: - Replace window

    func replaceWindow(_ engine: Engine, _ a: TileWindow, _ b: TileWindow) -> (() -> Void)? {
        var closure: (() -> Void)? = nil

        let checkRight = {
            if let right = self.right {
                switch right.kind {
                case .window(let e):
                    closure = { right.kind = .window(b.entity) }
                    _ = e
                case .stack(let data):
                    if let idx = stackFind(data, a.entity) {
                        closure = {
                            stackReplace(engine, data, b)
                            data.entities[idx] = b.entity
                        }
                    }
                default: break
                }
            }
        }

        switch left.kind {
        case .fork:
            checkRight()
        case .window(let e):
            if e == a.entity {
                closure = { self.left.kind = .window(b.entity) }
            } else {
                checkRight()
            }
        case .stack(let data):
            if let idx = stackFind(data, a.entity) {
                closure = {
                    stackReplace(engine, data, b)
                    data.entities[idx] = b.entity
                }
            } else {
                checkRight()
            }
        }

        return closure
    }

    // MARK: - Measurement (layout calculation)

    func measure(tiler: Forest, engine: Engine, area: Rect,
                 record: (Entity, Entity, Rect) -> Void) {
        var ratio: Double? = nil
        let manuallyMoved = engine.grabOp != nil || engine.tiler.resizingWindow

        if !isToplevel {
            if orientationChanged {
                orientationChanged = false
                let d = depth()
                ratio = d > 0 ? Double(lengthLeft) / Double(d) : prevRatio
            } else {
                let l = length()
                ratio = l > 0 ? Double(lengthLeft) / Double(l) : prevRatio
            }
            self.area = area.clone()
        } else if orientationChanged {
            orientationChanged = false
            let d = depth()
            ratio = d > 0 ? Double(lengthLeft) / Double(d) : prevRatio
        }

        if let ratio, ratio.isFinite {
            let l = length()
            if l > 0 {
                lengthLeft = Int((ratio * Double(l)).rounded())
            }
            if manuallyMoved { prevRatio = ratio }
        } else if manuallyMoved {
            let l = length()
            if l > 0 {
                prevRatio = Double(lengthLeft) / Double(l)
            }
        }

        if right != nil {
            let isHoriz = isHorizontal()
            let startpos = isHoriz ? self.area.x : self.area.y
            let totalLen = isHoriz ? self.area.width : self.area.height

            let half = totalLen / 2
            var len: Int

            // Snap to 32px grid, with dead zone around 50%
            if lengthLeft > half - 32 && lengthLeft < half + 32 {
                len = half
            } else {
                let diff = (startpos + lengthLeft) % 32
                len = lengthLeft - diff + (diff > 16 ? 32 : 0)
                if len == 0 { len = 32 }
            }

            // Left region
            var leftRegion = self.area.clone()
            if isHoriz {
                leftRegion.width = len - engine.gapInnerHalf
            } else {
                leftRegion.height = len - engine.gapInnerHalf
            }

            left.measure(tiler: tiler, engine: engine, parent: entity, area: leftRegion, record: record)

            // Right region
            var rightRegion = self.area.clone()
            if isHoriz {
                rightRegion.x = rightRegion.x + len + engine.gapInnerHalf
                rightRegion.width = totalLen - len - engine.gapInnerHalf
            } else {
                rightRegion.y = rightRegion.y + len + engine.gapInnerHalf
                rightRegion.height = totalLen - len - engine.gapInnerHalf
            }

            right!.measure(tiler: tiler, engine: engine, parent: entity, area: rightRegion, record: record)
        } else {
            left.measure(tiler: tiler, engine: engine, parent: entity, area: self.area, record: record)
        }
    }
}
