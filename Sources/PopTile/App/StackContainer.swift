// StackContainer.swift — Manages grouped/tabbed windows with visual tab bar
// Port of pop-shell src/stack.ts adapted for macOS

import AppKit

final class StackContainer {
    weak var engine: Engine?

    var active: Entity
    var activeId: Int = 0
    var prevActive: Entity? = nil
    var prevActiveId: Int = 0

    var monitor: Int
    var workspace: Int
    var tabsHeight: Int
    var stackData: StackData?

    private var tabBar: StackTabBar
    private var tabEntities: [Entity] = []

    init(engine: Engine, active: Entity, workspace: Int, monitor: Int) {
        self.engine = engine
        self.active = active
        self.monitor = monitor
        self.workspace = workspace
        self.tabsHeight = 28  // points — tab bar height
        self.tabBar = StackTabBar()
        self.tabBar.tabsHeight = CGFloat(tabsHeight)
        self.tabBar.setup { [weak self] entity in
            self?.onTabClicked(entity)
        }
        self.tabBar.onReorder = { [weak self] from, to in
            self?.reorderTab(from: from, to: to)
        }
    }

    // MARK: - Add

    func add(_ window: TileWindow) {
        let isActive = window.entity == active
        tabEntities.append(window.entity)

        tabBar.addTab(
            entity: window.entity,
            title: window.title(),
            icon: window.icon(),
            isActive: isActive,
            color: engine?.settings.hintColor ?? .systemCyan
        )
    }

    // MARK: - Activate

    func activate(_ entity: Entity) {
        guard let engine else { return }

        if entity != active {
            prevActive = active
            prevActiveId = activeId
        }

        active = entity

        for (idx, tabEntity) in tabEntities.enumerated() {
            guard let window = engine.windows.get(tabEntity) else { continue }

            if tabEntity == entity {
                activeId = idx
                // Show and raise the active window
                if window.axWindow.isMinimized() {
                    window.axWindow.setMinimized(false)
                }
                window.axWindow.raise()
            } else {
                // Position inactive windows at the same location but behind
                // They'll be occluded by the active window
            }
        }

        rebuildTabBar()
    }

    func autoActivate() -> Entity? {
        guard !tabEntities.isEmpty else { return nil }
        if activeId >= tabEntities.count {
            activeId = tabEntities.count - 1
        }
        let entity = tabEntities[activeId]
        activate(entity)
        return entity
    }

    func activatePrev() {
        if let prev = prevActive {
            activate(prev)
        }
    }

    // MARK: - Tab management

    func clear() {
        tabEntities.removeAll()
        tabBar.clear()
    }

    func deactivate(_ window: TileWindow) {
        // Show the window actor when deactivating from stack
    }

    func removeByPos(_ idx: Int) {
        guard idx < tabEntities.count else { return }
        tabEntities.remove(at: idx)
        rebuildTabBar()
    }

    func removeTab(_ entity: Entity) -> Int? {
        if let prev = prevActive, prev == entity {
            prevActive = nil
            prevActiveId = 0
        }

        if let idx = tabEntities.firstIndex(of: entity) {
            tabEntities.remove(at: idx)
            if activeId > idx {
                activeId -= 1
            }
            rebuildTabBar()
            return idx
        }
        return nil
    }

    func replace(_ window: TileWindow) {
        guard activeId < tabEntities.count else { return }
        tabEntities[activeId] = window.entity
        rebuildTabBar()
    }

    // MARK: - Positioning

    func updatePositions(_ rect: Rect) {
        tabBar.updatePositions(rect)
        tabBar.setVisible(true)
    }

    func setVisible(_ visible: Bool) {
        tabBar.setVisible(visible)
    }

    // MARK: - Destroy

    func destroy() {
        // Show all windows that were in this stack
        guard let engine else { return }
        for entity in tabEntities {
            if let window = engine.windows.get(entity) {
                if window.axWindow.isMinimized() {
                    window.axWindow.setMinimized(false)
                }
                window.stack = nil
            }
        }
        tabBar.destroy()
    }

    /// Refresh tab titles from current window titles (called on kAXTitleChangedNotification)
    func refreshTitles() {
        rebuildTabBar()
    }

    // MARK: - Reorder

    /// Move tab from one position to another, updating activeId and syncing to StackData.
    func reorderTab(from: Int, to: Int) {
        guard from != to,
              from >= 0, from < tabEntities.count,
              to >= 0, to < tabEntities.count else { return }

        let entity = tabEntities.remove(at: from)
        tabEntities.insert(entity, at: to)

        // Keep activeId pointing to the same entity
        if activeId == from {
            activeId = to
        } else if from < activeId && to >= activeId {
            activeId -= 1
        } else if from > activeId && to <= activeId {
            activeId += 1
        }

        // Sync to the backing StackData so the tree stays consistent
        stackData?.reorder(from: from, to: to)

        rebuildTabBar()
    }

    // MARK: - Test helpers

    /// Add an entity directly (for testing without TileWindow)
    func testAddEntity(_ entity: Entity) {
        tabEntities.append(entity)
    }

    /// Read-only access to tab entities (for test assertions)
    var testTabEntities: [Entity] { tabEntities }

    // MARK: - Private

    private func onTabClicked(_ entity: Entity) {
        activate(entity)
        if let window = engine?.windows.get(entity) {
            window.activate(false)
        }
    }

    private func rebuildTabBar() {
        guard let engine else { return }
        tabBar.clear()
        for entity in tabEntities {
            if let window = engine.windows.get(entity) {
                let isActive = entity == active
                tabBar.addTab(
                    entity: entity,
                    title: window.title(),
                    icon: window.icon(),
                    isActive: isActive,
                    color: engine.settings.hintColor
                )
            }
        }
    }
}
