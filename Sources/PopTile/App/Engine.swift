// Engine.swift — Main tiling engine (equivalent of pop-shell's Ext class)
// Coordinates between the tiling algorithm and macOS window management

import AppKit
import ApplicationServices

func log(_ message: String) {
    NSLog("[PopTile] %@", message)
}

// MARK: - Drag State

/// Tracks a window being dragged by the user (mirrors pop-shell's GrabOp)
struct DragState {
    let entity: Entity
    let originalRect: Rect
    var hintRect: Rect?
    var hintTarget: Entity?      // tiled window to attach next to
    var hintSide: Side?          // which side of the target
    var dropMonitor: Int?        // monitor to place on
}

final class Engine {
    // MARK: - Core state

    let windows: Storage<TileWindow> = Storage<TileWindow>()
    let monitors: Storage<(Int, Int)> = Storage<(Int, Int)>()  // entity -> (monitor, workspace)
    var autoTiler: AutoTiler?
    let tiler: Tiler = Tiler()
    let focusSelector: FocusSelector = FocusSelector()
    let settings: Settings = Settings()

    // MARK: - Platform

    var windowTracker: WindowTracker!
    var hotkeyManager: HotkeyManager = HotkeyManager()
    private let overlay: TilingOverlay = TilingOverlay()
    private let activeBorder: ActiveWindowBorder = ActiveWindowBorder()

    // MARK: - State

    var grabOp: GrabOp? = nil
    var overlayRect: Rect = .zero
    private var previousFocus: Entity? = nil
    private var currentFocus: Entity? = nil
    /// Window entity counter starts at 100_000 to avoid index collisions with
    /// Forest's fork entities (which use World's sequential 0,1,2... indices).
    /// This prevents Forest.deleteEntity from corrupting the `attached` storage
    /// when a fork entity's index coincides with a window entity's index.
    private var entityCounter: Int = 100_000

    /// Window identity map using CFEqual-based keys (NOT ObjectIdentifier)
    private var axToEntity: [AXElementKey: Entity] = [:]

    // MARK: - Tiling lock (suppress move events during our own tiling)

    var isPerformingTile: Bool = false

    // MARK: - Drag detection (mirrors pop-shell's grab_op + drag_signal)

    private var dragState: DragState? = nil
    /// Polling timer during drag: updates hint overlay AND checks for mouse-up
    /// (like pop-shell's GLib.timeout_add + grab-op-end)
    private var dragPollTimer: Timer? = nil
    private static let dragPollInterval: TimeInterval = 0.10
    /// Grace period after tiling before accepting move events as user drags
    private static let tileGracePeriod: CFAbsoluteTime = 0.5

    // MARK: - Computed

    var gapOuter: Int { settings.gapOuter }
    var gapInner: Int { settings.gapInner }
    var gapInnerHalf: Int { settings.gapInner / 2 }
    var dpi: CGFloat { NSScreen.main?.backingScaleFactor ?? 1.0 }
    var monitorCount: Int { NSScreen.screens.count }

    // MARK: - Initialization

    /// Timer that polls for accessibility permission when not yet granted
    private var accessibilityPollTimer: Timer?

    func start() {
        log(" Starting engine...")

        // Check accessibility permissions — prompt the user
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )

        if trusted {
            startEngine()
        } else {
            log(" Accessibility access not granted — polling until granted...")
            startAccessibilityPolling()
        }
    }

    private func startAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if AXIsProcessTrusted() {
                self.accessibilityPollTimer?.invalidate()
                self.accessibilityPollTimer = nil
                log(" Accessibility permission granted — starting engine")
                self.startEngine()
            }
        }
    }

    private func startEngine() {
        // Log monitor layout for diagnostics
        for (idx, screen) in NSScreen.screens.enumerated() {
            let axRect = screenToAXRect(screen)
            let workArea = screenWorkArea(screen)
            let isMain = screen == NSScreen.main
            let isBuiltin: Bool = {
                if let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                    return CGDisplayIsBuiltin(n) != 0
                }
                return false
            }()
            log(" Monitor \(idx): \(axRect.width)x\(axRect.height) at (\(axRect.x),\(axRect.y))" +
                " workArea=\(workArea.width)x\(workArea.height) at (\(workArea.x),\(workArea.y))" +
                " main=\(isMain) builtin=\(isBuiltin) shouldTile=\(settings.shouldTileMonitor(idx))")
        }

        // Setup auto-tiler
        if settings.autoTileEnabled {
            enableAutoTiling()
        }

        // Setup window tracker
        windowTracker = WindowTracker(engine: self)
        windowTracker.start()

        // Setup hotkeys
        setupHotkeys()
        hotkeyManager.start()

        log(" Engine started. Auto-tiling: \(settings.autoTileEnabled)")
    }

    func stop() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
        cancelDrag()
        windowTracker?.stop()
        hotkeyManager.stop()
        autoTiler?.destroy(self)
        autoTiler = nil
        log(" Engine stopped")
    }

    // MARK: - Auto tiling control

    func enableAutoTiling() {
        guard autoTiler == nil else { return }
        let forest = Forest()
        let attached: Storage<Entity> = forest.registerStorage()

        forest.connectOnAttach { [weak self] parent, child in
            guard self != nil else { return }
            attached.insert(child, parent)
        }

        forest.connectOnDetach { [weak self] child in
            guard self != nil else { return }
            attached.remove(child)
        }

        autoTiler = AutoTiler(forest: forest, attached: attached)
        log(" Auto-tiling enabled")

        // Re-tile all existing tracked windows (handles both startup and re-enable)
        isPerformingTile = true
        for (_, window) in windows.iter() {
            let monitorIdx = window.monitorIndex()
            if window.isTilable(self) && settings.shouldTileMonitor(monitorIdx) {
                autoTiler!.autoTile(self, window)
            }
        }
        isPerformingTile = false
    }

    func disableAutoTiling() {
        autoTiler?.destroy(self)
        autoTiler = nil
        log(" Auto-tiling disabled")
    }

    func toggleTiling() {
        if autoTiler != nil {
            disableAutoTiling()
        } else {
            enableAutoTiling()
        }
        settings.autoTileEnabled = (autoTiler != nil)
    }

    // MARK: - Window queries

    func focusWindow() -> TileWindow? {
        if let current = currentFocus, let win = windows.get(current) { return win }
        guard let axFocused = AXWindow.focusedWindow() else { return nil }
        return findTileWindow(axFocused.element)
    }

    func previouslyFocused(_ current: TileWindow) -> Entity? {
        guard let prev = previousFocus, prev != current.entity else { return nil }
        return prev
    }

    func activeWindowList() -> [TileWindow] {
        var result: [TileWindow] = []
        for (_, window) in windows.iter() {
            if window.actorExists() && !window.axWindow.isMinimized() && !window.axFailed {
                result.append(window)
            }
        }
        return result
    }

    // MARK: - Monitor queries

    func monitorWorkArea(_ monitor: Int) -> Rect {
        guard monitor < NSScreen.screens.count else { return .zero }
        return screenWorkArea(NSScreen.screens[monitor])
    }

    func activeWorkspace() -> Int {
        0  // macOS doesn't expose Spaces API; use workspace 0
    }

    func workspaceId(_ window: TileWindow) -> (Int, Int) {
        let monitor = window.monitorIndex()
        return (monitor, activeWorkspace())
    }

    // MARK: - Overlay

    func setOverlay(_ rect: Rect) {
        guard rect.width > 0 && rect.height > 0 else { return }
        overlayRect = rect
        overlay.update(rect: rect, color: settings.hintColor)
    }

    func showOverlay() {
        overlay.visible = true
    }

    func hideOverlay() {
        overlay.visible = false
    }

    // MARK: - Active window border

    func toggleActiveWindowBorder() {
        settings.showActiveWindowBorder.toggle()
        if settings.showActiveWindowBorder {
            if let win = focusWindow() {
                updateActiveBorder(win)
            }
        } else {
            activeBorder.hide()
        }
    }

    func updateActiveBorder(_ window: TileWindow) {
        guard settings.showActiveWindowBorder else {
            activeBorder.hide()
            return
        }
        // Don't show border over floating windows — they're already visually
        // distinct and the .floating-level overlay would cover their content
        if containsTag(window.entity, Tags.floating.rawValue) {
            activeBorder.hide()
            return
        }
        let rect = window.rect()
        guard rect.width > 0 && rect.height > 0 else { return }
        activeBorder.update(rect: rect, color: settings.hintColor,
                           borderRadius: CGFloat(settings.activeHintBorderRadius))
        activeBorder.show()
    }

    // MARK: - Tags

    func addTag(_ entity: Entity, _ tag: Int) {
        tagStorage[entity] = (tagStorage[entity] ?? Set()).union([tag])
    }

    func containsTag(_ entity: Entity, _ tag: Int) -> Bool {
        tagStorage[entity]?.contains(tag) ?? false
    }

    func deleteTag(_ entity: Entity, _ tag: Int) {
        tagStorage[entity]?.remove(tag)
    }

    private var tagStorage: [Entity: Set<Int>] = [:]

    // MARK: - Floating windows

    /// Raise all floating windows so they stay visually on top of tiled windows.
    func raiseFloatingWindows() {
        for (entity, tags) in tagStorage {
            if tags.contains(Tags.floating.rawValue),
               let window = windows.get(entity) {
                window.axWindow.raise()
            }
        }
    }

    // MARK: - Focus handling

    func focusLeft() {
        if let win = focusSelector.left(self, nil) { win.activate(true) }
    }

    func focusRight() {
        if let win = focusSelector.right(self, nil) { win.activate(true) }
    }

    func focusUp() {
        if let win = focusSelector.up(self, nil) { win.activate(true) }
    }

    func focusDown() {
        if let win = focusSelector.down(self, nil) { win.activate(true) }
    }

    // MARK: - Window events

    func onWindowCreated(_ axWin: AXWindow) {
        let key = AXElementKey(element: axWin.element)
        if axToEntity[key] != nil { return }

        let entity = createWindowEntity()
        let tileWin = TileWindow(entity: entity, axWindow: axWin)

        guard tileWin.isTilable(self) else { return }

        windows.insert(entity, tileWin)
        axToEntity[key] = entity

        let monitorIdx = tileWin.monitorIndex()
        monitors.insert(entity, (monitorIdx, activeWorkspace()))

        // Only auto-tile if this monitor is configured for tiling
        if let autoTiler, tileWin.isTilable(self), settings.shouldTileMonitor(monitorIdx) {
            isPerformingTile = true
            autoTiler.autoTile(self, tileWin)
            isPerformingTile = false
            let attached = autoTiler.attached.contains(tileWin.entity)
            let r = tileWin.rect()
            log(" Window added: \(tileWin.title()) on monitor \(monitorIdx) attached=\(attached) pos=(\(r.x),\(r.y)) size=\(r.width)x\(r.height)")
        } else {
            log(" Window added: \(tileWin.title()) on monitor \(monitorIdx) (not tiled)")
        }
    }

    func onWindowDestroyed(_ element: AXUIElement) {
        let key = AXElementKey(element: element)
        guard let entity = axToEntity.removeValue(forKey: key) else { return }

        if dragState?.entity == entity { cancelDrag() }

        if let autoTiler {
            isPerformingTile = true
            autoTiler.detachWindow(self, entity)
            isPerformingTile = false
        }

        let title = windows.get(entity)?.title() ?? "unknown"
        windows.remove(entity)
        monitors.remove(entity)
        tagStorage.removeValue(forKey: entity)

        if currentFocus == entity { currentFocus = nil }
        if previousFocus == entity { previousFocus = nil }

        log(" Window removed: \(title)")
    }

    func onFocusChanged() {
        guard let axFocused = AXWindow.focusedWindow() else { return }
        guard let tileWin = findTileWindow(axFocused.element) else { return }

        if currentFocus != tileWin.entity {
            previousFocus = currentFocus
            currentFocus = tileWin.entity
        }

        // If this window is in a stack, activate its tab
        if let stackIdx = tileWin.stack, let autoTiler,
           let container = autoTiler.forest.stacks.get(stackIdx) {
            container.activate(tileWin.entity)
        }

        // Update active window border
        updateActiveBorder(tileWin)

        // Keep floating windows on top (unless the focused window itself is floating)
        if !containsTag(tileWin.entity, Tags.floating.rawValue) {
            raiseFloatingWindows()
        }
    }

    func onWindowTitleChanged(_ element: AXUIElement) {
        guard let tileWin = findTileWindow(element) else { return }
        guard let stackIdx = tileWin.stack, let autoTiler,
              let container = autoTiler.forest.stacks.get(stackIdx) else { return }
        container.refreshTitles()
    }

    func onWindowMoved(_ element: AXUIElement) {
        guard !isPerformingTile else { return }
        guard let tileWin = findTileWindow(element) else { return }

        // Filter out async AX notifications from our own tiling moves.
        let now = CFAbsoluteTimeGetCurrent()
        if now - tileWin.lastTiledAt < Self.tileGracePeriod {
            return  // Still within grace period after our tiling
        }

        if let expected = tileWin.expectedRect {
            let current = tileWin.rect()
            let tolerance = 10
            if abs(current.x - expected.x) <= tolerance &&
               abs(current.y - expected.y) <= tolerance &&
               abs(current.width - expected.width) <= tolerance &&
               abs(current.height - expected.height) <= tolerance {
                return  // Window is still where we placed it — not a user drag
            }
            // Update expectedRect to current position so resize detection still has
            // a reference rect (setting to nil caused resize to silently fail because
            // fromRect would equal newRect → calculateMovement returns .none)
            tileWin.expectedRect = current
        }

        if let drag = dragState, drag.entity == tileWin.entity {
            return
        }

        guard let autoTiler else { return }
        guard autoTiler.attached.contains(tileWin.entity) else {
            log(" onWindowMoved SKIP \(tileWin.title()) — not attached")
            return
        }

        guard NSEvent.pressedMouseButtons & 1 != 0 else { return }

        startDrag(tileWin)
    }

    func onWindowResized(_ element: AXUIElement) {
        guard !isPerformingTile else { return }
        guard dragState == nil else { return }  // Don't handle resize during drag
        guard let tileWin = findTileWindow(element) else { return }

        // Filter out async AX notifications from our own tiling
        let now = CFAbsoluteTimeGetCurrent()
        if now - tileWin.lastTiledAt < Self.tileGracePeriod { return }

        guard let autoTiler else { return }

        guard let forkEntity = autoTiler.attached.get(tileWin.entity),
              let fork = autoTiler.forest.forks.get(forkEntity) else { return }

        let newRect = tileWin.rect()
        guard let fromRect = tileWin.expectedRect else {
            log(" onWindowResized SKIP \(tileWin.title()) — no expectedRect")
            return
        }
        let movement = calculateMovement(from: fromRect, change: newRect)

        if !movement.isEmpty && movement != .moved {
            log(" onWindowResized \(tileWin.title()) movement=\(movement) from=\(fromRect.width)x\(fromRect.height) to=\(newRect.width)x\(newRect.height)")
            grabOp = GrabOp(entity: tileWin.entity, rect: fromRect)
            autoTiler.forest.resize(self, forkEntity: forkEntity, fork: fork,
                                    winEntity: tileWin.entity, movement: movement,
                                    crect: newRect)
            isPerformingTile = true
            autoTiler.forest.arrange(self, fork.workspace)
            isPerformingTile = false
            grabOp = nil
            // Reset grace period for the user-resized window so continuous
            // drag-resize events are not suppressed by the 500ms grace period
            // (arrange sets lastTiledAt on ALL windows including this one)
            tileWin.lastTiledAt = 0
            // Update active border to follow the resized layout
            updateActiveBorder(tileWin)
        }
    }

    func onWindowMinimized(_ element: AXUIElement) {
        guard let entity = findEntity(element) else { return }
        if let autoTiler {
            isPerformingTile = true
            autoTiler.detachWindow(self, entity)
            isPerformingTile = false
        }
    }

    func removeWindowsForApp(_ pid: pid_t) {
        var toRemove: [(AXElementKey, Entity)] = []
        for (key, entity) in axToEntity {
            if let win = windows.get(entity), win.axWindow.pid == pid {
                toRemove.append((key, entity))
            }
        }
        isPerformingTile = true
        for (key, entity) in toRemove {
            if let autoTiler {
                autoTiler.detachWindow(self, entity)
            }
            windows.remove(entity)
            monitors.remove(entity)
            tagStorage.removeValue(forKey: entity)
            axToEntity.removeValue(forKey: key)
        }
        isPerformingTile = false
    }

    // MARK: - Drag-and-drop hint system (mirrors pop-shell's grab_op + overlay)
    //
    // Pop-shell flow:
    //   grab-op-begin → record state, start 200ms polling loop
    //   polling loop   → check cursor position, update overlay hint
    //   grab-op-end   → hide overlay, detach window, reattach at drop target
    //
    // macOS equivalent:
    //   kAXWindowMovedNotification → startDrag, start poll timer
    //   poll timer (150ms)        → updateDragHint based on cursor
    //   debounce (250ms no moves) → endDrag, perform reflow

    private func startDrag(_ window: TileWindow) {
        // Don't start a new drag if we're already dragging something
        if dragState != nil { return }

        dragState = DragState(
            entity: window.entity,
            originalRect: window.rect()
        )

        // Hide active border during drag to avoid visual clutter
        activeBorder.hide()

        log(" Drag started: \(window.title())")

        // Start polling timer: updates hint overlay AND checks for mouse-up
        // (combines pop-shell's GLib.timeout_add + grab-op-end signal)
        dragPollTimer?.invalidate()
        dragPollTimer = Timer.scheduledTimer(withTimeInterval: Self.dragPollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            // Check if mouse button released → end drag (like grab-op-end)
            if NSEvent.pressedMouseButtons & 1 == 0 {
                self.endDrag()
            } else {
                self.updateDragHint()
            }
        }

        // First hint update immediately
        updateDragHint()
    }

    private func updateDragHint() {
        guard let drag = dragState else { return }
        guard let autoTiler else { return }

        // Get cursor position in AX coordinates (top-left origin)
        let mouseScreenLoc = NSEvent.mouseLocation
        guard let mainScreen = NSScreen.screens.first else { return }
        let cursorX = Int(mouseScreenLoc.x)
        let cursorY = Int(mainScreen.frame.height - mouseScreenLoc.y)

        // Find which monitor the cursor is on
        var cursorMonitor = 0
        for (idx, screen) in NSScreen.screens.enumerated() {
            let r = screenToAXRect(screen)
            if cursorX >= r.x && cursorX < r.x + r.width &&
               cursorY >= r.y && cursorY < r.y + r.height {
                cursorMonitor = idx
                break
            }
        }

        let workArea = monitorWorkArea(cursorMonitor)
        guard workArea.width > 0 && workArea.height > 0 else { return }

        // Find the tiled window under the cursor (like pop-shell's windows_at_pointer)
        // Expand hit-test by gap size to cover gaps between tiles
        let hitExpand = gapInner + gapOuter
        var targetWindow: TileWindow? = nil
        var targetEntity: Entity? = nil

        var bestDist = Double.infinity
        for (entity, window) in windows.iter() {
            guard entity != drag.entity else { continue }
            guard autoTiler.attached.contains(entity) else { continue }
            guard window.monitorIndex() == cursorMonitor else { continue }

            let r = window.rect()
            // Expanded hit-test covers gap areas between tiles
            let inExpandedRect = cursorX >= r.x - hitExpand && cursorX < r.x + r.width + hitExpand &&
                                 cursorY >= r.y - hitExpand && cursorY < r.y + r.height + hitExpand

            if inExpandedRect {
                // Use distance to center as tiebreaker (prefer closer window)
                let dx = Double(cursorX - (r.x + r.width / 2))
                let dy = Double(cursorY - (r.y + r.height / 2))
                let dist = dx * dx + dy * dy
                if dist < bestDist {
                    bestDist = dist
                    targetWindow = window
                    targetEntity = entity
                }
            }
        }

        // Calculate hint zone using pop-shell's nearestSide approach
        var hintRect: Rect
        var hintSide: Side = .center

        // Edge margin: when cursor is within this distance of the monitor edge,
        // prefer splitting over stacking (prevents accidental stacking near edges)
        let edgeMargin = 100
        let nearLeft = cursorX - workArea.x < edgeMargin
        let nearRight = (workArea.x + workArea.width) - cursorX < edgeMargin
        let nearTop = cursorY - workArea.y < edgeMargin
        let nearBottom = (workArea.y + workArea.height) - cursorY < edgeMargin
        let nearEdge = nearLeft || nearRight || nearTop || nearBottom

        if let targetWindow, let targetEntity {
            let tr = targetWindow.rect()

            let cursor = (cursorX, cursorY)
            // Disable stacking when cursor is near screen edge
            let allowStacking = settings.stackingWithMouse && !nearEdge
            var (_, side) = nearestSide(origin: cursor, rect: tr,
                                        stackingWithMouse: allowStacking)

            // Near screen edge, override side to match the edge direction
            if nearEdge && side == .center {
                if nearLeft { side = .left }
                else if nearRight { side = .right }
                else if nearTop { side = .top }
                else { side = .bottom }
            }

            hintSide = side

            switch side {
            case .left:
                hintRect = Rect(x: tr.x, y: tr.y, width: tr.width / 2, height: tr.height)
            case .right:
                hintRect = Rect(x: tr.x + tr.width / 2, y: tr.y, width: tr.width / 2, height: tr.height)
            case .top:
                hintRect = Rect(x: tr.x, y: tr.y, width: tr.width, height: tr.height / 2)
            case .bottom:
                hintRect = Rect(x: tr.x, y: tr.y + tr.height / 2, width: tr.width, height: tr.height / 2)
            case .center:
                hintRect = tr
            }

            dragState?.hintTarget = targetEntity
            dragState?.hintSide = hintSide
            dragState?.dropMonitor = cursorMonitor
        } else {
            // No target window — suggest monitor placement (wider edge zones)
            let relX = Double(cursorX - workArea.x) / Double(max(1, workArea.width))
            let relY = Double(cursorY - workArea.y) / Double(max(1, workArea.height))

            if relX < 0.25 {
                hintRect = Rect(x: workArea.x + gapOuter, y: workArea.y + gapOuter,
                               width: workArea.width / 2 - gapOuter - gapInnerHalf,
                               height: workArea.height - gapOuter * 2)
                hintSide = .left
            } else if relX > 0.75 {
                let hw = workArea.width / 2
                hintRect = Rect(x: workArea.x + hw + gapInnerHalf, y: workArea.y + gapOuter,
                               width: hw - gapOuter - gapInnerHalf,
                               height: workArea.height - gapOuter * 2)
                hintSide = .right
            } else if relY < 0.25 {
                hintRect = Rect(x: workArea.x + gapOuter, y: workArea.y + gapOuter,
                               width: workArea.width - gapOuter * 2,
                               height: workArea.height / 2 - gapOuter - gapInnerHalf)
                hintSide = .top
            } else if relY > 0.75 {
                let hh = workArea.height / 2
                hintRect = Rect(x: workArea.x + gapOuter, y: workArea.y + hh + gapInnerHalf,
                               width: workArea.width - gapOuter * 2,
                               height: hh - gapOuter - gapInnerHalf)
                hintSide = .bottom
            } else {
                hintRect = Rect(x: workArea.x + gapOuter, y: workArea.y + gapOuter,
                               width: workArea.width - gapOuter * 2,
                               height: workArea.height - gapOuter * 2)
                hintSide = .center
            }

            dragState?.hintTarget = nil
            dragState?.hintSide = hintSide
            dragState?.dropMonitor = cursorMonitor
        }

        dragState?.hintRect = hintRect
        setOverlay(hintRect)
        showOverlay()
    }

    /// Called when dragging stops (like pop-shell's grab-op-end + on_drop)
    private func endDrag() {
        guard let drag = dragState, let autoTiler else {
            cancelDrag()
            return
        }
        guard let window = windows.get(drag.entity) else {
            cancelDrag()
            return
        }

        hideOverlay()
        dragPollTimer?.invalidate()
        dragPollTimer = nil

        isPerformingTile = true

        // Detach from current position
        autoTiler.detachWindow(self, window.entity)

        if let target = drag.hintTarget, let targetWin = windows.get(target) {
            let side = drag.hintSide ?? .center

            if side == .center {
                // Stack/group with target — create or join a tab group
                stackWindowOnto(autoTiler, window: window, target: targetWin)
                log(" Drop: stacked \(window.title()) with \(targetWin.title())")
            } else {
                // Split: place next to target on the specified side
                let orient: Orientation = (side == .left || side == .right) ? .horizontal : .vertical
                let swap = (side == .left || side == .top)
                let moveBy = MoveBy.cursor(orientation: orient, swap: swap)

                if !autoTiler.attachToWindow(self, targetWin, window, moveBy, stackFromLeft: true) {
                    autoTiler.attachToWorkspace(self, window, workspaceId(window))
                }
                log(" Drop: placed \(window.title()) \(side) of \(targetWin.title())")
            }
        } else if let monitor = drag.dropMonitor {
            autoTiler.attachToWorkspace(self, window, (monitor, activeWorkspace()))
            log(" Drop: tiled \(window.title()) on monitor \(monitor)")
        } else {
            autoTiler.attachToWorkspace(self, window, workspaceId(window))
        }

        isPerformingTile = false
        dragState = nil

        // Re-show active window border after tiling
        updateActiveBorder(window)
    }

    private func cancelDrag() {
        hideOverlay()
        dragState = nil
        dragPollTimer?.invalidate()
        dragPollTimer = nil
    }

    // MARK: - Stacking helpers

    /// Add a window to a target's stack, or create a new stack containing both
    private func stackWindowOnto(_ autoTiler: AutoTiler, window: TileWindow, target: TileWindow) {
        guard let forkEntity = autoTiler.attached.get(target.entity),
              let fork = autoTiler.forest.forks.get(forkEntity) else {
            // Target not attached — just tile normally
            autoTiler.attachToWorkspace(self, window, workspaceId(window))
            return
        }

        // Check if target is already in a stack
        if fork.left.isInStack(target.entity), let stackData = fork.left.stackData {
            _ = autoTiler.forest.attachStack(self, stackData, fork, window.entity, stackFromLeft: true)
            autoTiler.tile(self, fork, fork.area)
            return
        }
        if let right = fork.right, right.isInStack(target.entity), let stackData = right.stackData {
            _ = autoTiler.forest.attachStack(self, stackData, fork, window.entity, stackFromLeft: true)
            autoTiler.tile(self, fork, fork.area)
            return
        }

        // Target is a regular window — convert it to a stack first, then add the new window
        autoTiler.createStack(self, target)

        // Now re-read the fork (createStack modifies it)
        guard let fork2 = autoTiler.forest.forks.get(forkEntity) else {
            autoTiler.attachToWorkspace(self, window, workspaceId(window))
            return
        }

        if fork2.left.isInStack(target.entity), let stackData = fork2.left.stackData {
            _ = autoTiler.forest.attachStack(self, stackData, fork2, window.entity, stackFromLeft: true)
            autoTiler.tile(self, fork2, fork2.area)
        } else if let right = fork2.right, right.isInStack(target.entity), let stackData = right.stackData {
            _ = autoTiler.forest.attachStack(self, stackData, fork2, window.entity, stackFromLeft: true)
            autoTiler.tile(self, fork2, fork2.area)
        } else {
            // Fallback
            autoTiler.attachToWorkspace(self, window, workspaceId(window))
        }
    }

    // MARK: - Per-app tiling control

    func detachAppWindows(bundleId: String) {
        guard let autoTiler else { return }
        isPerformingTile = true
        for (_, window) in windows.iter() {
            if let app = NSRunningApplication(processIdentifier: window.axWindow.pid),
               app.bundleIdentifier == bundleId,
               autoTiler.attached.contains(window.entity) {
                autoTiler.detachWindow(self, window.entity)
            }
        }
        isPerformingTile = false
    }

    func retileAppWindows(bundleId: String) {
        guard let autoTiler else { return }
        isPerformingTile = true
        for (_, window) in windows.iter() {
            if let app = NSRunningApplication(processIdentifier: window.axWindow.pid),
               app.bundleIdentifier == bundleId,
               window.isTilable(self),
               !autoTiler.attached.contains(window.entity) {
                autoTiler.autoTile(self, window)
            }
        }
        isPerformingTile = false
    }

    // MARK: - Retile all

    func retileAll() {
        guard let autoTiler else { return }

        isPerformingTile = true

        // Re-measure and arrange all existing toplevel forks without rebuilding the tree.
        // This recalculates positions based on current monitor areas and gap settings.
        for (_, (entity, id)) in autoTiler.forest.toplevel {
            if let fork = autoTiler.forest.forks.get(entity) {
                autoTiler.updateToplevel(self, fork, id.0, smartGaps: settings.smartGaps)
            }
        }

        isPerformingTile = false
        raiseFloatingWindows()
    }

    // MARK: - Private helpers

    private func createWindowEntity() -> Entity {
        entityCounter += 1
        return Entity(index: entityCounter, generation: 0)
    }

    func findTileWindow(_ element: AXUIElement) -> TileWindow? {
        let key = AXElementKey(element: element)
        guard let entity = axToEntity[key] else { return nil }
        return windows.get(entity)
    }

    private func findEntity(_ element: AXUIElement) -> Entity? {
        let key = AXElementKey(element: element)
        return axToEntity[key]
    }

    // MARK: - Hotkey setup

    func setupHotkeys() {
        let ctrlOpt: NSEvent.ModifierFlags = [.control, .option]
        let ctrlOptShift: NSEvent.ModifierFlags = [.control, .option, .shift]

        // Focus direction: Ctrl+Option + Arrow/HJKL
        hotkeyManager.register(KeyCode.leftArrow, ctrlOpt) { [weak self] in self?.focusLeft() }
        hotkeyManager.register(KeyCode.rightArrow, ctrlOpt) { [weak self] in self?.focusRight() }
        hotkeyManager.register(KeyCode.upArrow, ctrlOpt) { [weak self] in self?.focusUp() }
        hotkeyManager.register(KeyCode.downArrow, ctrlOpt) { [weak self] in self?.focusDown() }
        hotkeyManager.register(KeyCode.h, ctrlOpt) { [weak self] in self?.focusLeft() }
        hotkeyManager.register(KeyCode.l, ctrlOpt) { [weak self] in self?.focusRight() }
        hotkeyManager.register(KeyCode.k, ctrlOpt) { [weak self] in self?.focusUp() }
        hotkeyManager.register(KeyCode.j, ctrlOpt) { [weak self] in self?.focusDown() }

        // Move window: Ctrl+Option+Shift + Arrow
        hotkeyManager.register(KeyCode.leftArrow, ctrlOptShift) { [weak self] in
            guard let self else { return }
            self.tiler.moveLeft(self, self.focusWindow()?.entity)
        }
        hotkeyManager.register(KeyCode.rightArrow, ctrlOptShift) { [weak self] in
            guard let self else { return }
            self.tiler.moveRight(self, self.focusWindow()?.entity)
        }
        hotkeyManager.register(KeyCode.upArrow, ctrlOptShift) { [weak self] in
            guard let self else { return }
            self.tiler.moveUp(self, self.focusWindow()?.entity)
        }
        hotkeyManager.register(KeyCode.downArrow, ctrlOptShift) { [weak self] in
            guard let self else { return }
            self.tiler.moveDown(self, self.focusWindow()?.entity)
        }

        // Toggle orientation: Ctrl+Option+O
        hotkeyManager.register(KeyCode.o, ctrlOpt) { [weak self] in
            guard let self else { return }
            self.tiler.toggleOrientation(self)
        }

        // Toggle stacking: Ctrl+Option+S
        hotkeyManager.register(KeyCode.s, ctrlOpt) { [weak self] in
            guard let self else { return }
            self.tiler.toggleStacking(self)
        }

        // Toggle floating: Ctrl+Option+G
        hotkeyManager.register(KeyCode.g, ctrlOpt) { [weak self] in
            guard let self else { return }
            self.autoTiler?.toggleFloating(self)
            if let win = self.focusWindow() {
                self.updateActiveBorder(win)
            }
        }

        // Toggle auto-tiling: Ctrl+Option+T
        hotkeyManager.register(KeyCode.t, ctrlOpt) { [weak self] in
            self?.toggleTiling()
        }

        // Enter tiling mode: Ctrl+Option+Return
        hotkeyManager.register(KeyCode.returnKey, ctrlOpt) { [weak self] in
            guard let self else { return }
            self.tiler.enter(self)
        }

        // Retile all: Ctrl+Option+R
        hotkeyManager.register(KeyCode.r, ctrlOpt) { [weak self] in
            self?.retileAll()
        }

        // Toggle active window border: Ctrl+Option+B
        hotkeyManager.register(KeyCode.b, ctrlOpt) { [weak self] in
            self?.toggleActiveWindowBorder()
        }

        // Exit tiling mode: Ctrl+Option+Escape
        hotkeyManager.register(KeyCode.escape, ctrlOpt) { [weak self] in
            guard let self else { return }
            self.tiler.exit(self)
        }

        // Move with HJKL: Ctrl+Option+Shift + HJKL
        hotkeyManager.register(KeyCode.h, ctrlOptShift) { [weak self] in
            guard let self else { return }
            self.tiler.moveLeft(self, self.focusWindow()?.entity)
        }
        hotkeyManager.register(KeyCode.l, ctrlOptShift) { [weak self] in
            guard let self else { return }
            self.tiler.moveRight(self, self.focusWindow()?.entity)
        }
        hotkeyManager.register(KeyCode.k, ctrlOptShift) { [weak self] in
            guard let self else { return }
            self.tiler.moveUp(self, self.focusWindow()?.entity)
        }
        hotkeyManager.register(KeyCode.j, ctrlOptShift) { [weak self] in
            guard let self else { return }
            self.tiler.moveDown(self, self.focusWindow()?.entity)
        }

        // Resize: Ctrl+Option + [ / ]
        hotkeyManager.register(KeyCode.leftBracket, ctrlOpt) { [weak self] in
            guard let self else { return }
            self.tiler.resize(self, .left)
        }
        hotkeyManager.register(KeyCode.rightBracket, ctrlOpt) { [weak self] in
            guard let self else { return }
            self.tiler.resize(self, .right)
        }
    }
}

// MARK: - Test helpers

extension Engine {
    /// Whether the active window border overlay is currently visible (for testing)
    var isActiveBorderVisible: Bool {
        activeBorder.visible
    }

    /// Force the active border to show at a given rect (for testing)
    func showActiveBorderForTesting(rect: Rect) {
        activeBorder.update(rect: rect, color: settings.hintColor)
        activeBorder.show()
    }
}
