// main.swift — Entry point for PopTile
// Pop!_OS Shell tiling window manager, ported to macOS

import AppKit
import PopTileCore

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Set activation policy to accessory (menu bar only, no Dock icon)
app.setActivationPolicy(.accessory)

app.run()
