// AppDelegate.swift — NSApplication delegate with status bar item

import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let engine = Engine()

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        engine.start()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }

    // MARK: - Status bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // Use a system symbol for the tiling icon
            if let image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "PopTile") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "PT"
            }
        }

        let menu = NSMenu()

        // Auto-tiling toggle
        let tilingItem = NSMenuItem(title: "Auto-Tiling", action: #selector(toggleTiling), keyEquivalent: "")
        tilingItem.target = self
        tilingItem.state = engine.settings.autoTileEnabled ? .on : .off
        menu.addItem(tilingItem)

        menu.addItem(NSMenuItem.separator())

        // Gap settings
        let gapMenu = NSMenu()
        for gap in [0, 2, 4, 8, 12, 16] {
            let item = NSMenuItem(title: "\(gap)px", action: #selector(setGap(_:)), keyEquivalent: "")
            item.target = self
            item.tag = gap
            item.state = engine.settings.gapOuter == gap ? .on : .off
            gapMenu.addItem(item)
        }
        let gapItem = NSMenuItem(title: "Gap Size", action: nil, keyEquivalent: "")
        gapItem.submenu = gapMenu
        menu.addItem(gapItem)

        menu.addItem(NSMenuItem.separator())

        // Display tiling mode
        let displayMenu = NSMenu()
        for (title, mode) in [("All Displays", "all"), ("Main Display Only", "main"), ("External Displays Only", "external")] {
            let item = NSMenuItem(title: title, action: #selector(setDisplayMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            item.state = engine.settings.tilingDisplayMode == mode ? .on : .off
            displayMenu.addItem(item)
        }
        let displayItem = NSMenuItem(title: "Tile Displays", action: nil, keyEquivalent: "")
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)

        menu.addItem(NSMenuItem.separator())

        // Retile all
        let retileItem = NSMenuItem(title: "Retile All Windows", action: #selector(retileAll), keyEquivalent: "r")
        retileItem.target = self
        retileItem.keyEquivalentModifierMask = [.control, .option]
        menu.addItem(retileItem)

        menu.addItem(NSMenuItem.separator())

        // Shortcuts reference
        let shortcutsItem = NSMenuItem(title: "Keyboard Shortcuts...", action: #selector(showShortcuts), keyEquivalent: "")
        shortcutsItem.target = self
        menu.addItem(shortcutsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit PopTile", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleTiling() {
        engine.toggleTiling()
        // Update menu item state
        if let menu = statusItem.menu, let item = menu.items.first {
            item.state = engine.settings.autoTileEnabled ? .on : .off
        }
    }

    @objc private func setDisplayMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String else { return }
        engine.settings.tilingDisplayMode = mode

        // Update menu checkmarks
        if let displayMenu = sender.menu {
            for item in displayMenu.items {
                item.state = (item.representedObject as? String) == mode ? .on : .off
            }
        }

        // Retile with new display config
        engine.retileAll()
    }

    @objc private func setGap(_ sender: NSMenuItem) {
        let gap = sender.tag
        engine.settings.gapOuter = gap
        engine.settings.gapInner = gap

        // Update menu checkmarks
        if let gapMenu = sender.menu {
            for item in gapMenu.items {
                item.state = item.tag == gap ? .on : .off
            }
        }

        // Retile with new gaps
        engine.retileAll()
    }

    @objc private func retileAll() {
        engine.retileAll()
    }

    @objc private func showShortcuts() {
        let alert = NSAlert()
        alert.messageText = "PopTile Keyboard Shortcuts"
        alert.informativeText = """
        Focus Window:
          Ctrl+Option + Arrow Keys (or H/J/K/L)

        Move Window:
          Ctrl+Option+Shift + Arrow Keys

        Toggle Orientation:
          Ctrl+Option + O

        Toggle Stacking (group windows):
          Ctrl+Option + S

        Toggle Floating:
          Ctrl+Option + G

        Toggle Auto-Tiling:
          Ctrl+Option + T

        Enter Tiling Mode:
          Ctrl+Option + Return

        Resize:
          Ctrl+Option + [ / ]

        Note: Modifier is Ctrl+Option (equivalent to
        Pop!_OS Super key behavior).
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
