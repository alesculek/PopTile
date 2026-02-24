# PopTile

Auto-tiling window manager for macOS, ported from [pop-shell](https://github.com/pop-os/shell) by [System76](https://system76.com/).

The tiling algorithm (binary space partitioning, fork trees, stacking) is a Swift port of pop-shell's TypeScript implementation. PopTile adapts it for macOS using the Accessibility API (AXUIElement) instead of GNOME's Mutter.

Supports multiple monitors, keyboard-driven navigation, window stacking (tab groups), and configurable gaps.

## Installation

### Download (recommended)

1. Download the latest `PopTile-macos-arm64.zip` from [Releases](https://github.com/alesculek/PopTile/releases)
2. Unzip and place `PopTile` somewhere in your PATH (e.g. `/usr/local/bin/`)
3. Run `PopTile` — it appears as a status bar icon
4. Grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility)

### Build from source

Requires Xcode Command Line Tools (macOS 14+).

```bash
git clone https://github.com/alesculek/PopTile.git
cd PopTile
swift build -c release
cp .build/release/PopTile /usr/local/bin/
```

## Usage

PopTile runs as a menu bar app. Click the grid icon for controls:

- **Auto-Tiling** — enable/disable
- **Float Current App** — toggle tiling for the focused app
- **Float Exceptions...** — manage apps that should never tile
- **Gap Size** — set pixel gap between tiles
- **Tile Displays** — choose which monitors to tile (all / main / external)
- **Retile All Windows** — re-apply tiling layout

### Keyboard Shortcuts

| Action | Shortcut |
|---|---|
| Focus window | Ctrl+Option + Arrow Keys (or H/J/K/L) |
| Move window | Ctrl+Option+Shift + Arrow Keys |
| Toggle orientation | Ctrl+Option + O |
| Toggle stacking | Ctrl+Option + S |
| Toggle floating | Ctrl+Option + G |
| Toggle auto-tiling | Ctrl+Option + T |
| Enter tiling mode | Ctrl+Option + Return |
| Resize | Ctrl+Option + [ / ] |

## Known Limitations

- **Electron apps** (Slack, VS Code, Discord, etc.) may not expose windows to the macOS Accessibility API. If an app's windows aren't tiled, it's likely because the app doesn't support AX window discovery. Check the log for "No AX windows" messages.
- **Minimum window size** — some apps enforce a minimum size. When many windows tile on a small screen, tiles may be too small and apps will silently ignore the resize.
- **macOS Accessibility permission** is required. PopTile cannot function without it.

## Credits

PopTile is a macOS port of [pop-shell](https://github.com/pop-os/shell), the auto-tiling window manager extension for GNOME, created by [System76](https://system76.com/) and contributors. The core tiling logic (forest, forks, stacking, auto-tiler) is derived from their work.

## License

GPL-3.0 — see [LICENSE](LICENSE).

This project is a derivative work of [pop-shell](https://github.com/pop-os/shell), which is licensed under the GNU General Public License v3.0.
