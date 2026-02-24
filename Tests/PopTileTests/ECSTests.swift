@testable import PopTileCore
import XCTest

final class EntityTests: XCTestCase {

    func testEntityEquality() {
        let a = Entity(index: 1, generation: 0)
        let b = Entity(index: 1, generation: 0)
        let c = Entity(index: 1, generation: 1)
        let d = Entity(index: 2, generation: 0)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c, "Different generation")
        XCTAssertNotEqual(a, d, "Different index")
    }

    func testEntityHashable() {
        let a = Entity(index: 1, generation: 0)
        let b = Entity(index: 1, generation: 0)
        var set = Set<Entity>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }
}

final class StorageTests: XCTestCase {

    func testInsertAndGet() {
        let storage = Storage<String>()
        let entity = Entity(index: 0, generation: 0)
        storage.insert(entity, "hello")
        XCTAssertEqual(storage.get(entity), "hello")
    }

    func testGetMissing() {
        let storage = Storage<String>()
        let entity = Entity(index: 0, generation: 0)
        XCTAssertNil(storage.get(entity))
    }

    func testGenerationMismatch() {
        let storage = Storage<String>()
        let e0 = Entity(index: 0, generation: 0)
        let e1 = Entity(index: 0, generation: 1)
        storage.insert(e0, "gen0")
        XCTAssertNil(storage.get(e1), "Wrong generation should return nil")
    }

    func testRemove() {
        let storage = Storage<String>()
        let entity = Entity(index: 0, generation: 0)
        storage.insert(entity, "hello")
        let removed = storage.remove(entity)
        XCTAssertEqual(removed, "hello")
        XCTAssertNil(storage.get(entity))
    }

    func testContains() {
        let storage = Storage<Int>()
        let e = Entity(index: 0, generation: 0)
        XCTAssertFalse(storage.contains(e))
        storage.insert(e, 42)
        XCTAssertTrue(storage.contains(e))
    }

    func testIsEmpty() {
        let storage = Storage<Int>()
        XCTAssertTrue(storage.isEmpty())
        let e = Entity(index: 0, generation: 0)
        storage.insert(e, 1)
        XCTAssertFalse(storage.isEmpty())
        storage.remove(e)
        XCTAssertTrue(storage.isEmpty())
    }

    func testGetOrInsert() {
        let storage = Storage<Int>()
        let e = Entity(index: 0, generation: 0)
        let val = storage.getOrInsert(e) { 42 }
        XCTAssertEqual(val, 42)
        // Second call should return existing value
        let val2 = storage.getOrInsert(e) { 99 }
        XCTAssertEqual(val2, 42)
    }

    func testIter() {
        let storage = Storage<String>()
        let e0 = Entity(index: 0, generation: 0)
        let e1 = Entity(index: 1, generation: 0)
        storage.insert(e0, "a")
        storage.insert(e1, "b")

        var found: [String] = []
        for (_, value) in storage.iter() {
            found.append(value)
        }
        XCTAssertEqual(found.sorted(), ["a", "b"])
    }

    func testMultipleEntities() {
        let storage = Storage<Int>()
        for i in 0..<100 {
            storage.insert(Entity(index: i, generation: 0), i * 10)
        }
        XCTAssertEqual(storage.get(Entity(index: 50, generation: 0)), 500)
        XCTAssertEqual(storage.get(Entity(index: 99, generation: 0)), 990)
        XCTAssertNil(storage.get(Entity(index: 100, generation: 0)))
    }
}

final class WorldTests: XCTestCase {

    func testCreateEntity() {
        let world = World()
        let e1 = world.createEntity()
        let e2 = world.createEntity()
        XCTAssertNotEqual(e1, e2)
        XCTAssertEqual(e1.index, 0)
        XCTAssertEqual(e2.index, 1)
    }

    func testDeleteAndRecreate() {
        let world = World()
        let e1 = world.createEntity()
        XCTAssertEqual(e1.generation, 0)

        world.deleteEntity(e1)

        let e2 = world.createEntity()
        XCTAssertEqual(e2.index, e1.index, "Should reuse slot")
        XCTAssertEqual(e2.generation, 1, "Generation should increment")
    }

    func testTags() {
        let world = World()
        let e = world.createEntity()
        XCTAssertFalse(world.containsTag(e, 1))
        world.addTag(e, 1)
        XCTAssertTrue(world.containsTag(e, 1))
        world.deleteTag(e, 1)
        XCTAssertFalse(world.containsTag(e, 1))
    }

    func testRegisteredStorageCleanup() {
        let world = World()
        let storage: Storage<String> = world.registerStorage()

        let e = world.createEntity()
        storage.insert(e, "test")
        XCTAssertEqual(storage.get(e), "test")

        world.deleteEntity(e)
        XCTAssertNil(storage.get(e), "Deleting entity should clean up registered storages")
    }

    func testLength() {
        let world = World()
        XCTAssertEqual(world.length, 0)
        let e1 = world.createEntity()
        let _ = world.createEntity()
        XCTAssertEqual(world.length, 2)
        world.deleteEntity(e1)
        XCTAssertEqual(world.length, 1)
    }
}
