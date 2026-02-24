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

## Release

When asked to release, follow these steps:

1. **Bump version** in `Sources/PopTile/Resources/Info.plist` (both `CFBundleVersion` and `CFBundleShortVersionString`).

2. **Run tests**: `swift test` — all must pass.

3. **Commit & push**:
   ```bash
   git add -A && git commit -m "Release vX.Y.Z" && git push
   ```

4. **Build release .app bundle**:
   ```bash
   swift build -c release
   mkdir -p /private/tmp/poptile-release/PopTile.app/Contents/MacOS \
            /private/tmp/poptile-release/PopTile.app/Contents/Resources
   cp .build/release/PopTile /private/tmp/poptile-release/PopTile.app/Contents/MacOS/
   cp Sources/PopTile/Resources/Info.plist /private/tmp/poptile-release/PopTile.app/Contents/
   codesign --force --deep --sign - /private/tmp/poptile-release/PopTile.app
   cd /private/tmp/poptile-release && zip -r PopTile-vX.Y.Z-macos-arm64.zip PopTile.app
   ```

5. **Create GitHub release**:
   ```bash
   gh release create vX.Y.Z /private/tmp/poptile-release/PopTile-vX.Y.Z-macos-arm64.zip \
     --title "PopTile vX.Y.Z" --notes "Release notes here"
   ```

6. **Update Homebrew cask** at `/opt/homebrew/Library/Taps/alesculek/homebrew-tap/Casks/poptile.rb`:
   - Update `version` to the new version
   - Compute sha256: `shasum -a 256 /private/tmp/poptile-release/PopTile-vX.Y.Z-macos-arm64.zip`
   - Update `sha256` in the cask
   - Commit & push: `cd /opt/homebrew/Library/Taps/alesculek/homebrew-tap && git add -A && git commit -m "Update poptile to vX.Y.Z" && git push`

7. **Update local install**: `brew upgrade --cask poptile` or reinstall.

8. **Signing for dev**: The dev cert "PopTile Dev" (SHA: 280C74949E7439587233AEF7BAD0EB5666059A9D) is in the login keychain. Use `codesign --force --deep --sign "PopTile Dev" ~/Applications/PopTile.app` when installing locally to preserve TCC accessibility permissions across rebuilds.
