// TileWindow.swift — Managed window (equivalent of pop-shell ShellWindow)
// Wraps AXWindow with tiling state

import AppKit

final class TileWindow {
    let entity: Entity
    var axWindow: AXWindow
    var stack: Int? = nil
    var ignoreDetach: Bool = false
    var smartGapped: Bool = false
    var knownWorkspace: Int = 0

    init(entity: Entity, axWindow: AXWindow) {
        self.entity = entity
        self.axWindow = axWindow
    }

    func rect() -> Rect {
        let frame = axWindow.frame()
        return Rect(from: frame)
    }

    func move(_ engine: Engine, _ rect: Rect, completion: (() -> Void)? = nil) {
        if !axWindow.setFrame(rect.cgRect) {
            axFailed = true
        }
        completion?()
    }

    func title() -> String {
        axWindow.title() ?? "Unknown"
    }

    var axFailed: Bool = false
    /// The position we last tiled this window to (used to distinguish our moves from user drags)
    var expectedRect: Rect? = nil
    /// Timestamp of last tile operation (used as grace period for async AX notifications)
    var lastTiledAt: CFAbsoluteTime = 0

    func isTilable(_ engine: Engine) -> Bool {
        if axFailed { return false }
        guard axWindow.isValid() else { return false }
        guard axWindow.isStandardWindow() else { return false }
        if axWindow.isMinimized() { return false }
        if axWindow.isFullscreen() { return false }

        // Check if this app should float
        if let bundleId = NSRunningApplication(processIdentifier: axWindow.pid)?.bundleIdentifier {
            if engine.settings.shouldFloat(bundleId: bundleId) {
                // Float exception: only tile if explicitly force-tiled
                return engine.containsTag(entity, Tags.forceTile.rawValue)
            }
        }

        // Skip very small windows (likely tooltips/popups)
        let size = axWindow.size()
        if size.width < 200 || size.height < 100 { return false }

        return true
    }

    func activate(_ warpPointer: Bool) {
        // Activate the owning app
        if let app = NSRunningApplication(processIdentifier: axWindow.pid) {
            app.activate()
        }
        axWindow.raise()
        axWindow.focus()
    }

    func isMaximized() -> Bool {
        let r = rect()
        let screenRect = monitorWorkArea()
        return r.x <= screenRect.x + 5 &&
               r.y <= screenRect.y + 5 &&
               r.width >= screenRect.width - 10 &&
               r.height >= screenRect.height - 10
    }

    func actorExists() -> Bool {
        axWindow.isValid()
    }

    func icon() -> NSImage? {
        axWindow.appIcon()
    }

    /// Determine which monitor this window is primarily on
    func monitorIndex() -> Int {
        let frame = axWindow.frame()
        let center = CGPoint(x: frame.midX, y: frame.midY)

        for (idx, screen) in NSScreen.screens.enumerated() {
            // Convert screen frame to AX coordinates
            let screenRect = screenToAXRect(screen)
            if center.x >= CGFloat(screenRect.x) && center.x < CGFloat(screenRect.x + screenRect.width) &&
               center.y >= CGFloat(screenRect.y) && center.y < CGFloat(screenRect.y + screenRect.height) {
                return idx
            }
        }
        return 0
    }

    private func monitorWorkArea() -> Rect {
        let idx = monitorIndex()
        guard idx < NSScreen.screens.count else { return .zero }
        return screenWorkArea(NSScreen.screens[idx])
    }
}

/// Get work area for a screen in AX coordinates (excludes menu bar and dock)
func screenWorkArea(_ screen: NSScreen) -> Rect {
    let visibleFrame = screen.visibleFrame
    guard let mainScreen = NSScreen.screens.first else { return Rect(from: visibleFrame) }
    let screenHeight = mainScreen.frame.height

    // Convert to AX coordinates (top-left origin)
    let y = Int(screenHeight - visibleFrame.origin.y - visibleFrame.size.height)
    return Rect(x: Int(visibleFrame.origin.x), y: y,
                width: Int(visibleFrame.size.width), height: Int(visibleFrame.size.height))
}

/// Convert NSScreen frame to AX coordinates
func screenToAXRect(_ screen: NSScreen) -> Rect {
    guard let mainScreen = NSScreen.screens.first else {
        return Rect(from: screen.frame)
    }
    let screenHeight = mainScreen.frame.height
    let y = Int(screenHeight - screen.frame.origin.y - screen.frame.size.height)
    return Rect(x: Int(screen.frame.origin.x), y: y,
                width: Int(screen.frame.size.width), height: Int(screen.frame.size.height))
}
