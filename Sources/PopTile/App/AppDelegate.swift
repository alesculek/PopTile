// AppDelegate.swift — NSApplication delegate with status bar item

import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let engine = Engine()
    private lazy var floatConfigWindow = FloatConfigWindow(settings: engine.settings)

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
            if let image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "PopTile") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "PT"
            }
        }

        let menu = NSMenu()
        menu.delegate = self

        // Auto-tiling toggle
        let tilingItem = NSMenuItem(title: "Auto-Tiling", action: #selector(toggleTiling), keyEquivalent: "")
        tilingItem.target = self
        tilingItem.state = engine.settings.autoTileEnabled ? .on : .off
        menu.addItem(tilingItem)

        menu.addItem(NSMenuItem.separator())

        // Float current app toggle (dynamic label)
        let floatItem = NSMenuItem(title: "Float Current App", action: #selector(toggleFloatCurrentApp), keyEquivalent: "")
        floatItem.target = self
        floatItem.tag = 100  // tag to find this item for dynamic update
        menu.addItem(floatItem)

        // Float exceptions config window
        let floatConfigItem = NSMenuItem(title: "Float Exceptions...", action: #selector(showFloatConfig), keyEquivalent: "")
        floatConfigItem.target = self
        menu.addItem(floatConfigItem)

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

        // Active window border toggle
        let borderItem = NSMenuItem(title: "Active Window Border", action: #selector(toggleActiveWindowBorder), keyEquivalent: "")
        borderItem.target = self
        borderItem.tag = 200
        borderItem.state = engine.settings.showActiveWindowBorder ? .on : .off
        menu.addItem(borderItem)

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

        // About
        let aboutItem = NSMenuItem(title: "About PopTile", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit PopTile", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleTiling() {
        engine.toggleTiling()
        if let menu = statusItem.menu, let item = menu.items.first {
            item.state = engine.settings.autoTileEnabled ? .on : .off
        }
    }

    @objc private func toggleFloatCurrentApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else { return }

        if engine.settings.shouldFloat(bundleId: bundleId) {
            engine.settings.removeFloatException(bundleId)
            log(" Removed float exception: \(bundleId) (\(frontApp.localizedName ?? ""))")
            // Re-tile this app's windows
            engine.retileAppWindows(bundleId: bundleId)
        } else {
            engine.settings.addFloatException(bundleId)
            log(" Added float exception: \(bundleId) (\(frontApp.localizedName ?? ""))")
            // Detach this app's windows from tiling
            engine.detachAppWindows(bundleId: bundleId)
        }
    }

    @objc private func toggleActiveWindowBorder() {
        engine.toggleActiveWindowBorder()
        if let menu = statusItem.menu, let item = menu.item(withTag: 200) {
            item.state = engine.settings.showActiveWindowBorder ? .on : .off
        }
    }

    @objc private func showFloatConfig() {
        floatConfigWindow.show()
    }

    @objc private func removeFloatException(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }
        engine.settings.removeFloatException(bundleId)
        log(" Removed float exception: \(bundleId)")
    }

    @objc private func setDisplayMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String else { return }
        engine.settings.tilingDisplayMode = mode

        if let displayMenu = sender.menu {
            for item in displayMenu.items {
                item.state = (item.representedObject as? String) == mode ? .on : .off
            }
        }

        engine.retileAll()
    }

    @objc private func setGap(_ sender: NSMenuItem) {
        let gap = sender.tag
        engine.settings.gapOuter = gap
        engine.settings.gapInner = gap

        if let gapMenu = sender.menu {
            for item in gapMenu.items {
                item.state = item.tag == gap ? .on : .off
            }
        }

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

        Active Window Border:
          Ctrl+Option + B

        Note: Modifier is Ctrl+Option (equivalent to
        Pop!_OS Super key behavior).
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let alert = NSAlert()
        alert.messageText = "PopTile v\(version)"
        alert.informativeText = """
        Auto-tiling window manager for macOS.
        Ported from pop-shell by System76.

        https://github.com/alesculek/PopTile
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        if let appIcon = NSImage(named: NSImage.applicationIconName) {
            alert.icon = appIcon
        }

        alert.runModal()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Dynamic menu updates

extension AppDelegate: NSMenuDelegate {
    public func menuNeedsUpdate(_ menu: NSMenu) {
        // Update "Float Current App" item
        if let floatItem = menu.item(withTag: 100) {
            if let frontApp = NSWorkspace.shared.frontmostApplication,
               let bundleId = frontApp.bundleIdentifier {
                let name = frontApp.localizedName ?? bundleId
                let isFloated = engine.settings.shouldFloat(bundleId: bundleId)
                floatItem.title = isFloated ? "Tile \(name)" : "Float \(name)"
                floatItem.state = isFloated ? .on : .off
            } else {
                floatItem.title = "Float Current App"
                floatItem.state = .off
            }
        }

    }
}
