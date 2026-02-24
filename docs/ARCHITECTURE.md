# PopTile Architecture

## Overview

PopTile is a macOS port of Pop!_OS's pop-shell tiling window manager. The core tiling
algorithm is a direct 1:1 port from the TypeScript source, with the platform integration
layer adapted for macOS.

## Pop-Shell Source Analysis

### Repository
- Source: https://github.com/pop-os/shell (branch: master_jammy, GNOME 42-44)
- Language: TypeScript, compiled as GNOME Shell extension
- Reference clone: `../pop-shell-reference/`

### Core Data Structures (ported exactly)

| Pop-Shell File | PopTile File | Description |
|---|---|---|
| `src/ecs.ts` | `Core/ECS.swift` | Entity Component System - generational entity IDs, Storage<T>, World |
| `src/arena.ts` | `Core/Arena.swift` | Hop-slot arena allocator for stacks/tabs |
| `src/rectangle.ts` | `Core/Rect.swift` | Rectangle with geometry operations |
| `src/node.ts` | `Core/Node.swift` | Node ADT: Fork/Window/Stack + stack operations |
| `src/fork.ts` | `Core/Fork.swift` | Binary fork: left/right children, orientation, ratio, measure() |
| `src/forest.ts` | `Core/Forest.swift` | Tree collection: attach/detach/resize/measure/arrange |
| `src/auto_tiler.ts` | `Core/AutoTiler.swift` | Orchestrator: auto-tile, toggle stacking/floating/orientation |
| `src/tiling.ts` | `Core/Tiler.swift` | Keyboard tiling mode: move, resize, swap, enter/accept/exit |
| `src/focus.ts` | `Core/Tiler.swift` | FocusSelector: directional window focus |
| `src/geom.ts` | `Core/Geometry.swift` | Geometry: distance, nearest_side, shortest_side |
| `src/movement.ts` | `Core/Geometry.swift` | Movement flags (grow/shrink + direction) |

### Tiling Algorithm

Pop-shell uses a **dynamic binary tree** (NOT BSP). Key properties:

1. **One tree per monitor+workspace** - stored as `toplevel` in Forest
2. **Each Fork has left (always present) and optional right child**
3. **Orientation** is either horizontal or vertical per fork
4. **Ratio** (`lengthLeft`) determines the split point between left/right
5. **Measurement** is recursive top-down via `Fork.measure()`:
   - Calculates target rectangles for all windows
   - Snaps to 32px grid with dead zone around 50%
   - Records results via callback
6. **Arrangement** applies recorded moves in batch via `Forest.arrange()`
7. **Attach**: new windows are inserted next to the focused window, splitting its space
8. **Detach**: removed windows cause tree compression (sibling promoted to parent)
9. **Rebalance**: fork orientation auto-adjusts based on aspect ratio

### Stacking (Tabbed Window Groups)

Pop-shell's most distinctive feature. In the tree, a `NodeStack` occupies a fork branch:
- Contains multiple window entities sharing the same screen space
- Only the active tab's window is visible
- Visual tab bar rendered above the stack area
- Windows can be moved in/out of stacks with keyboard shortcuts

### Key Algorithms to Preserve

- `Forest.attachWindow()` — how new windows join the tree
- `Forest.detach()` — tree compression on window removal
- `Fork.measure()` — recursive layout with 32px grid snapping
- `Forest.resize()` — tree-walking to find the right fork to resize
- `AutoTiler.autoTile()` — preference for tiling next to focused window
- Stack move left/right — reorder tabs or detach at edges

## macOS Platform Layer

### What's Different from GNOME

| Aspect | Pop-Shell (GNOME) | PopTile (macOS) |
|---|---|---|
| Window control | Mutter compositor API | Accessibility API (AXUIElement) |
| Events | GObject signals | AXObserver + NSWorkspace notifications |
| Hotkeys | GNOME Shell keybinding API | CGEventTap |
| Overlay | GNOME Shell Clutter actors | Transparent NSWindow (floating level) |
| Tab bar | St.BoxLayout in compositor | NSWindow + NSStackView overlay |
| Window show/hide | Clutter actor.show()/hide() | Raise active, others occluded |
| Workspaces | Native via Mutter | Single workspace (Spaces API is private) |
| Decorations | Controlled by Mutter | App-owned, cannot be removed |

### Platform Files

| File | Purpose |
|---|---|
| `Platform/AXWindow.swift` | Wraps AXUIElement: read/write position, size, raise, focus |
| `Platform/WindowTracker.swift` | AXObserver per-app + NSWorkspace for lifecycle events |
| `Platform/HotkeyManager.swift` | CGEventTap for global keyboard shortcut interception |
| `Platform/Overlay.swift` | TilingOverlay (hint border) + StackTabBar (tab bar UI) |

### App Files

| File | Purpose |
|---|---|
| `App/Engine.swift` | Main coordinator (equiv of pop-shell Ext class) |
| `App/TileWindow.swift` | Managed window wrapping AXWindow with tiling state |
| `App/StackContainer.swift` | Port of Stack class for tabbed window groups |
| `App/Settings.swift` | UserDefaults-based settings (gaps, colors, etc.) |
| `App/AppDelegate.swift` | NSApplication delegate, status bar menu |

### Coordinate System

Both pop-shell (GNOME/Mutter) and macOS Accessibility API use **top-left origin**
(y increases downward). The tiling algorithm works identically.

NSScreen uses bottom-left origin. Conversion only needed for NSWindow overlays:
- `axToScreen()` and `screenToAX()` in Overlay.swift handle this.

### Permissions Required

1. **Accessibility** (System Settings > Privacy & Security > Accessibility)
   - Required for AXUIElement window control
   - Prompted on first launch via `AXIsProcessTrustedWithOptions`

2. **Input Monitoring** (System Settings > Privacy & Security > Input Monitoring)
   - Required for CGEventTap keyboard interception
   - Prompted when event tap is created

## What Cannot Be Ported 1:1

1. **Native Spaces/virtual desktops**: No public API. We use workspace=0 for everything.
   (yabai solves this by injecting into Dock.app, requiring SIP disabled)

2. **Window decorations**: Cannot remove title bars. Pop-shell can control Mutter decorations.

3. **Z-order control**: Limited. Active stack window is raised, others are behind it
   (pop-shell hides/shows compositor actors directly).

4. **Reliable event ordering**: AX events can arrive out of order or be missing.
   Pop-shell benefits from Mutter's compositor-level event guarantees.

5. **Performance**: Accessibility API can stall under load. Pop-shell operates at
   compositor level with microsecond latency.

6. **App non-cooperation**: Some macOS apps set minimum sizes or ignore position changes.
   The AX API cannot override an application's internal constraints.

## Keyboard Shortcuts

Modifier mapping: Pop!_OS `Super` key → macOS `Ctrl+Option`

| Action | Pop!_OS | PopTile (macOS) |
|---|---|---|
| Focus left/right/up/down | Super+Arrow/HJKL | Ctrl+Option+Arrow/HJKL |
| Move window | Super+Shift+Arrow | Ctrl+Option+Shift+Arrow |
| Toggle orientation | Super+O | Ctrl+Option+O |
| Toggle stacking | Super+S | Ctrl+Option+S |
| Toggle floating | Super+G | Ctrl+Option+G |
| Toggle auto-tiling | - | Ctrl+Option+T |
| Enter tiling mode | Super+Return | Ctrl+Option+Return |
| Resize | Super+Arrow (in tiling mode) | Ctrl+Option+[ / ] |
