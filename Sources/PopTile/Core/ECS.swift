// ECS.swift — Entity Component System
// Direct port of pop-shell src/ecs.ts
//
// Generational entity IDs solve the ABA problem by tagging indexes with generations.

import Foundation

/// A generational entity ID: (index, generation)
struct Entity: Hashable, Equatable, CustomStringConvertible {
    let index: Int
    let generation: Int

    var description: String { "(\(index),\(generation))" }

    static func == (a: Entity, b: Entity) -> Bool {
        a.index == b.index && a.generation == b.generation
    }
}

/// Storages hold components of a specific type, keyed by entity.
/// Uses generational sparse array with entity ID as index.
final class Storage<T> {
    private var store: [(generation: Int, value: T)?] = []

    func iter() -> AnySequence<(Entity, T)> {
        AnySequence(store.enumerated().lazy.compactMap { idx, slot in
            guard let slot else { return nil }
            return (Entity(index: idx, generation: slot.generation), slot.value)
        })
    }

    func values() -> AnySequence<T> {
        AnySequence(store.lazy.compactMap { $0?.value })
    }

    func contains(_ entity: Entity) -> Bool {
        get(entity) != nil
    }

    func get(_ entity: Entity) -> T? {
        guard entity.index < store.count, let slot = store[entity.index],
              slot.generation == entity.generation else { return nil }
        return slot.value
    }

    func getOrInsert(_ entity: Entity, _ initializer: () -> T) -> T {
        if let value = get(entity) { return value }
        let value = initializer()
        insert(entity, value)
        return value
    }

    func insert(_ entity: Entity, _ component: T) {
        while store.count <= entity.index {
            store.append(nil)
        }
        store[entity.index] = (entity.generation, component)
    }

    func isEmpty() -> Bool {
        store.allSatisfy { $0 == nil }
    }

    @discardableResult
    func remove(_ entity: Entity) -> T? {
        guard let comp = get(entity) else { return nil }
        store[entity.index] = nil
        return comp
    }

    /// Remove and pass to callback
    @discardableResult
    func takeWith<X>(_ entity: Entity, _ fn: (T) -> X) -> X? {
        guard let comp = remove(entity) else { return nil }
        return fn(comp)
    }

    /// Apply function if component exists
    @discardableResult
    func with<X>(_ entity: Entity, _ fn: (T) -> X) -> X? {
        guard let comp = get(entity) else { return nil }
        return fn(comp)
    }

    /// Apply mutating function if component exists
    func withMut(_ entity: Entity, _ fn: (inout T) -> Void) {
        guard entity.index < store.count, var slot = store[entity.index],
              slot.generation == entity.generation else { return }
        fn(&slot.value)
        store[entity.index] = slot
    }
}

/// Protocol to allow Storage erasure for bulk entity deletion
protocol AnyStorage: AnyObject {
    func removeAny(_ entity: Entity)
}

extension Storage: AnyStorage {
    func removeAny(_ entity: Entity) {
        remove(entity)
    }
}

/// The World maintains all entities and their component storages.
class World {
    private var entities_: [Entity] = []
    private var storages: [AnyStorage] = []
    private var tags_: [Set<Int>] = []
    private var freeSlots: Set<Int> = []

    var capacity: Int { entities_.count }
    var freeCount: Int { freeSlots.count }
    var length: Int { capacity - freeCount }

    func tags(_ entity: Entity) -> Set<Int> {
        guard entity.index < tags_.count else { return [] }
        return tags_[entity.index]
    }

    func allEntities() -> AnySequence<Entity> {
        AnySequence(entities_.lazy.filter { entity in
            !self.freeSlots.contains(entity.index)
        })
    }

    func createEntity() -> Entity {
        if let slot = freeSlots.first {
            freeSlots.remove(slot)
            let old = entities_[slot]
            let entity = Entity(index: old.index, generation: old.generation + 1)
            entities_[slot] = entity
            return entity
        } else {
            let entity = Entity(index: capacity, generation: 0)
            entities_.append(entity)
            tags_.append(Set())
            return entity
        }
    }

    func deleteEntity(_ entity: Entity) {
        // Guard against double-delete: only proceed if the slot is not already free
        guard entity.index < entities_.count,
              !freeSlots.contains(entity.index) else { return }

        if entity.index < tags_.count {
            tags_[entity.index].removeAll()
        }
        for storage in storages {
            storage.removeAny(entity)
        }
        freeSlots.insert(entity.index)
    }

    func addTag(_ entity: Entity, _ tag: Int) {
        guard entity.index < tags_.count else { return }
        tags_[entity.index].insert(tag)
    }

    func containsTag(_ entity: Entity, _ tag: Int) -> Bool {
        guard entity.index < tags_.count else { return false }
        return tags_[entity.index].contains(tag)
    }

    func deleteTag(_ entity: Entity, _ tag: Int) {
        guard entity.index < tags_.count else { return }
        tags_[entity.index].remove(tag)
    }

    func registerStorage<T>() -> Storage<T> {
        let storage = Storage<T>()
        storages.append(storage)
        return storage
    }
}
