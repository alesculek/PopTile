# macOS Platform Research

## Window Management APIs

### Primary: Accessibility API (AXUIElement)

Every macOS tiling WM uses this. C-based API in ApplicationServices framework.

**Reading:**
```swift
AXUIElementCopyAttributeValue(window, kAXPositionAttribute, &value)
AXUIElementCopyAttributeValue(window, kAXSizeAttribute, &value)
```

**Writing:**
```swift
AXUIElementSetAttributeValue(window, kAXPositionAttribute, posValue)
AXUIElementSetAttributeValue(window, kAXSizeAttribute, sizeValue)
```

**Key technique (from Rectangle.app):** Set size, then position, then size again.
macOS enforces sizes that fit on the current display.

### Secondary: CGWindowListCopyWindowInfo

Read-only. Enumerates windows but cannot modify them.

### Private APIs (NOT used in PopTile)

- `CGSSpace` APIs (SkyLight.framework) — managing Spaces
- `_AXUIElementGetWindow` — maps AXUIElement to CGWindowID
- Dock.app injection — yabai's approach, requires SIP disabled

## Limitations vs Linux

| Capability | Linux (X11/Wayland) | macOS |
|---|---|---|
| Full window placement control | Yes (WM authority) | Partial (AX API) |
| Control window decorations | Yes | No (apps own chrome) |
| Native workspace control | Yes | No public API |
| Z-order control | Yes | Very limited |
| Reliable event ordering | Yes | No (AX events can be out-of-order) |
| Performance | Compositor-level | AX API can stall under load |

## Existing macOS Tiling Managers

### yabai (C)
- Most powerful, BSP algorithm
- Injects scripting addition into Dock.app for full features
- Requires SIP partially disabled

### AeroSpace (Swift)
- Emulates own workspace system (avoids Spaces API)
- Only one private API used (`_AXUIElementGetWindow`)
- i3-compatible commands

### Amethyst (Swift)
- Pure Accessibility API
- Multiple layout algorithms
- JavaScript custom layouts

### Rectangle (Swift)
- Not a tiling WM, but keyboard/snap window positioning
- Clean AXUIElement reference code

## Global Keyboard Shortcuts

### CGEventTap (used by PopTile)
- Can modify/consume events
- Requires Input Monitoring permission
- Used by yabai's skhd, AeroSpace

### NSEvent.addGlobalMonitorForEvents
- Cannot consume events (they still reach other apps)
- Not suitable for window manager

## Window Events

### AXObserver (per-app)
- kAXWindowCreatedNotification
- kAXUIElementDestroyedNotification
- kAXFocusedWindowChangedNotification
- kAXWindowMovedNotification
- kAXWindowResizedNotification
- Must create one per running application PID

### NSWorkspace Notifications
- didLaunchApplicationNotification
- didTerminateApplicationNotification
- didActivateApplicationNotification

## Required Permissions

1. **Accessibility** — System Settings > Privacy & Security > Accessibility
2. **Input Monitoring** — System Settings > Privacy & Security > Input Monitoring
3. **Cannot be sandboxed** — no Mac App Store distribution
4. SIP disabled NOT required (we don't inject into Dock.app)

## Coordinate System

- AX API: top-left origin (y=0 at top) — matches GNOME/Mutter
- NSScreen: bottom-left origin (y=0 at bottom)
- Conversion: `y_screen = screenHeight - ax_y - height`
