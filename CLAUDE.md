# PopTile

macOS port of Pop!_OS pop-shell auto-tiling window manager using AXUIElement.

## Build & Run

```bash
swift build && .build/debug/PopTile > /tmp/poptile.log 2>&1 &
```

## Test

```bash
swift test
```

All tests are in `Tests/PopTileTests/`. Add tests for every new feature.

## Architecture

- **Sources/PopTile/Core/** — Tiling algorithm (ported from pop-shell TypeScript). Pure logic, no AppKit.
  - `ECS.swift` — Entity-Component-System (Entity, Storage, World, Arena)
  - `Forest.swift` — Fork tree collection, measure/arrange, attach/detach
  - `Fork.swift` — Binary tiling fork with ratio-based splitting
  - `Node.swift` — Fork tree node (window, fork, or stack)
  - `AutoTiler.swift` — Orchestrates auto-tiling, stacking, floating
  - `Tiler.swift` — Keyboard-driven move/resize/orientation
  - `Geometry.swift` — Distance, nearestSide, calculateMovement
  - `Rect.swift` — Integer rectangle with NaN safety

- **Sources/PopTile/App/** — Application layer
  - `Engine.swift` — Main coordinator. Drag detection, window events, hotkeys
  - `TileWindow.swift` — Managed window wrapping AXWindow with tiling state
  - `AppDelegate.swift` — Status bar menu, toggle actions
  - `Settings.swift` — UserDefaults-backed settings (gaps, display mode, float exceptions)
  - `StackContainer.swift` — Tab group container
  - `FloatConfigWindow.swift` — Float exceptions configuration UI

- **Sources/PopTile/Platform/** — macOS integration
  - `AXWindow.swift` — AXUIElement wrapper (read/write attributes, setFrame)
  - `WindowTracker.swift` — AXObserver + NSWorkspace window discovery
  - `HotkeyManager.swift` — CGEvent tap for Ctrl+Opt shortcuts
  - `Overlay.swift` — Hint overlay + stack tab bar NSWindows

- **Sources/PopTileApp/main.swift** — Thin executable entry point

## Key Patterns

- **Drag detection**: Mouse-button polling (100ms) replaces debounce. `expectedRect` + `lastTiledAt` grace period (500ms) filters out async AX notifications from our own tiling.
- **AX setFrame**: Does size→position→size (3 operations), each generates separate AX notifications.
- **Coordinate system**: AX uses top-left origin. `screenToAXRect`/`axToScreen` convert to/from AppKit bottom-left.
- **Fork tree**: Binary tree of windows. Each monitor+workspace gets a toplevel fork. Splitting adds sub-forks.

## Package Structure

SPM with 3 targets:
- `PopTileCore` (library) — everything in Sources/PopTile/
- `PopTile` (executable) — Sources/PopTileApp/main.swift
- `PopTileTests` — Tests/PopTileTests/

Test target imports `@testable import PopTileCore`.
