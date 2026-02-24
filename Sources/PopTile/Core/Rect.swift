// Rect.swift — Rectangle type
// Direct port of pop-shell src/rectangle.ts

import Foundation
import CoreGraphics

struct Rect: Equatable, CustomStringConvertible {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    static let zero = Rect(x: 0, y: 0, width: 0, height: 0)

    var description: String { "Rect(\(x),\(y),\(width),\(height))" }

    var cgRect: CGRect {
        CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
    }

    init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ array: [Int]) {
        precondition(array.count == 4)
        self.x = array[0]
        self.y = array[1]
        self.width = array[2]
        self.height = array[3]
    }

    init(from cgRect: CGRect) {
        self.x = cgRect.origin.x.isFinite ? Int(cgRect.origin.x) : 0
        self.y = cgRect.origin.y.isFinite ? Int(cgRect.origin.y) : 0
        self.width = cgRect.size.width.isFinite ? Int(cgRect.size.width) : 0
        self.height = cgRect.size.height.isFinite ? Int(cgRect.size.height) : 0
    }

    func clone() -> Rect {
        Rect(x: x, y: y, width: width, height: height)
    }

    mutating func apply(_ other: Rect) {
        x += other.x
        y += other.y
        width += other.width
        height += other.height
    }

    func applied(_ other: Rect) -> Rect {
        var r = self
        r.apply(other)
        return r
    }

    mutating func clamp(_ other: Rect) {
        x = max(other.x, x)
        y = max(other.y, y)

        let tendX = x + width
        let oendX = other.x + other.width
        if tendX > oendX { width = oendX - x }

        let tendY = y + height
        let oendY = other.y + other.height
        if tendY > oendY { height = oendY - y }
    }

    func contains(_ other: Rect) -> Bool {
        x <= other.x &&
        y <= other.y &&
        x + width >= other.x + other.width &&
        y + height >= other.y + other.height
    }

    func diff(_ other: Rect) -> Rect {
        Rect(x: other.x - x, y: other.y - y, width: other.width - width, height: other.height - height)
    }

    func intersects(_ other: Rect) -> Bool {
        x < other.x + other.width &&
        x + width > other.x &&
        y < other.y + other.height &&
        y + height > other.y
    }
}
