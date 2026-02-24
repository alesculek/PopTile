// Geometry.swift — Geometry, Movement, Direction, and Orientation types
// Port of pop-shell src/geom.ts, src/movement.ts, src/lib.ts (enums)

import Foundation

// MARK: - Orientation

enum Orientation: Int {
    case horizontal = 0
    case vertical = 1
}

// MARK: - Direction

enum Direction {
    case left, up, right, down
}

// MARK: - Side

enum Side {
    case left, top, right, bottom, center
}

// MARK: - Movement Flags

struct Movement: OptionSet {
    let rawValue: Int

    static let none    = Movement([])
    static let moved   = Movement(rawValue: 0b1)
    static let grow    = Movement(rawValue: 0b10)
    static let shrink  = Movement(rawValue: 0b100)
    static let left    = Movement(rawValue: 0b1000)
    static let up      = Movement(rawValue: 0b10000)
    static let right   = Movement(rawValue: 0b100000)
    static let down    = Movement(rawValue: 0b1000000)
}

func calculateMovement(from: Rect, change: Rect) -> Movement {
    let xpos = from.x == change.x
    let ypos = from.y == change.y

    if xpos && ypos {
        if from.width == change.width {
            if from.height == change.height {
                return .none
            } else if from.height < change.height {
                return [.grow, .down]
            } else {
                return [.shrink, .up]
            }
        } else if from.width < change.width {
            return [.grow, .right]
        } else {
            return [.shrink, .left]
        }
    } else if xpos {
        if from.height < change.height {
            return [.grow, .up]
        } else {
            return [.shrink, .down]
        }
    } else if ypos {
        if from.width < change.width {
            return [.grow, .left]
        } else {
            return [.shrink, .right]
        }
    } else {
        return .moved
    }
}

// MARK: - Geometry Functions

func xend(_ r: Rect) -> Int { r.x + r.width }
func xcenter(_ r: Rect) -> Int { r.x + r.width / 2 }
func yend(_ r: Rect) -> Int { r.y + r.height }
func ycenter(_ r: Rect) -> Int { r.y + r.height / 2 }

func center(_ r: Rect) -> (Int, Int) { (xcenter(r), ycenter(r)) }
func north(_ r: Rect) -> (Int, Int) { (xcenter(r), r.y) }
func east(_ r: Rect) -> (Int, Int) { (xend(r), ycenter(r)) }
func south(_ r: Rect) -> (Int, Int) { (xcenter(r), yend(r)) }
func west(_ r: Rect) -> (Int, Int) { (r.x, ycenter(r)) }

func distance(_ a: (Int, Int), _ b: (Int, Int)) -> Double {
    let dx = Double(b.0 - a.0)
    let dy = Double(b.1 - a.1)
    return sqrt(dx * dx + dy * dy)
}

func directionalDistance(_ a: Rect, _ b: Rect,
                         _ fnA: (Rect) -> (Int, Int),
                         _ fnB: (Rect) -> (Int, Int)) -> Double {
    distance(fnA(a), fnB(b))
}

func upwardDistance(_ a: Rect, _ b: Rect) -> Double {
    directionalDistance(a, b, south, north)
}

func rightwardDistance(_ a: Rect, _ b: Rect) -> Double {
    directionalDistance(a, b, west, east)
}

func downwardDistance(_ a: Rect, _ b: Rect) -> Double {
    directionalDistance(a, b, north, south)
}

func leftwardDistance(_ a: Rect, _ b: Rect) -> Double {
    directionalDistance(a, b, east, west)
}

func nearestSide(origin: (Int, Int), rect: Rect, stackingWithMouse: Bool = false) -> (Double, Side) {
    let l = west(rect), t = north(rect), r = east(rect), b = south(rect), c = center(rect)

    let ld = distance(origin, l)
    let td = distance(origin, t)
    let rd = distance(origin, r)
    let bd = distance(origin, b)
    let cd = distance(origin, c)

    var nearest: (Double, Side) = ld < rd ? (ld, .left) : (rd, .right)
    if td < nearest.0 { nearest = (td, .top) }
    if bd < nearest.0 { nearest = (bd, .bottom) }
    if stackingWithMouse && cd < nearest.0 { nearest = (cd, .center) }

    return nearest
}

func shortestSide(origin: (Int, Int), rect: Rect) -> Double {
    var shortest = distance(origin, west(rect))
    shortest = min(shortest, distance(origin, north(rect)))
    shortest = min(shortest, distance(origin, east(rect)))
    return min(shortest, distance(origin, south(rect)))
}

func roundIncrement(_ value: Int, _ increment: Int) -> Int {
    guard increment > 0 else { return value }
    return Int((Double(value) / Double(increment)).rounded()) * increment
}
