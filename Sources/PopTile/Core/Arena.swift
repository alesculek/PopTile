// Arena.swift — Hop-slot arena allocator
// Direct port of pop-shell src/arena.ts

import Foundation

final class Arena<T> {
    private var slots: [T?] = []
    private var unused: [Int] = []

    func truncate(_ n: Int) {
        if n < slots.count {
            slots.removeSubrange(n...)
        }
        unused.removeAll { $0 >= n }
    }

    func get(_ n: Int) -> T? {
        guard n < slots.count else { return nil }
        return slots[n]
    }

    @discardableResult
    func insert(_ value: T) -> Int {
        if let slot = unused.popLast() {
            slots[slot] = value
            return slot
        } else {
            let n = slots.count
            slots.append(value)
            return n
        }
    }

    @discardableResult
    func remove(_ n: Int) -> T? {
        guard n < slots.count, let value = slots[n] else { return nil }
        slots[n] = nil
        unused.append(n)
        return value
    }

    func values() -> AnySequence<T> {
        AnySequence(slots.lazy.compactMap { $0 })
    }
}
