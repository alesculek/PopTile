// Settings.swift — User-configurable settings (equivalent of pop-shell GSettings)

import AppKit

final class Settings {
    private let defaults = UserDefaults.standard

    // MARK: - Gap settings (pixels)

    var gapOuter: Int {
        get { defaults.object(forKey: "gapOuter") as? Int ?? 4 }
        set { defaults.set(newValue, forKey: "gapOuter") }
    }

    var gapInner: Int {
        get { defaults.object(forKey: "gapInner") as? Int ?? 4 }
        set { defaults.set(newValue, forKey: "gapInner") }
    }

    // MARK: - Smart gaps

    var smartGaps: Bool {
        get { defaults.object(forKey: "smartGaps") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "smartGaps") }
    }

    // MARK: - Auto-tiling

    var autoTileEnabled: Bool {
        get { defaults.object(forKey: "autoTileEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoTileEnabled") }
    }

    // MARK: - Display tiling mode

    /// Which displays to tile: "all", "main", "external"
    /// - "all": tile all displays (default)
    /// - "main": only tile the main/built-in display
    /// - "external": only tile external displays
    var tilingDisplayMode: String {
        get { defaults.string(forKey: "tilingDisplayMode") ?? "all" }
        set { defaults.set(newValue, forKey: "tilingDisplayMode") }
    }

    /// Check if a monitor index should be tiled based on tilingDisplayMode
    func shouldTileMonitor(_ monitorIndex: Int) -> Bool {
        let screens = NSScreen.screens
        guard monitorIndex < screens.count else { return false }

        switch tilingDisplayMode {
        case "main":
            return screens[monitorIndex] == NSScreen.main
        case "external":
            let screen = screens[monitorIndex]
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                return CGDisplayIsBuiltin(screenNumber) == 0
            }
            return true  // If we can't determine, assume external
        default:
            return true
        }
    }

    // MARK: - Appearance

    var hintColor: NSColor {
        get {
            if let data = defaults.data(forKey: "hintColor"),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            return .systemCyan
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                defaults.set(data, forKey: "hintColor")
            }
        }
    }

    var activeHintBorderRadius: Int {
        get { defaults.object(forKey: "activeHintBorderRadius") as? Int ?? 8 }
        set { defaults.set(newValue, forKey: "activeHintBorderRadius") }
    }

    var stackingWithMouse: Bool {
        get { defaults.object(forKey: "stackingWithMouse") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "stackingWithMouse") }
    }

    var showActiveWindowBorder: Bool {
        get { defaults.object(forKey: "showActiveWindowBorder") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "showActiveWindowBorder") }
    }

    // MARK: - Auto-grouping threshold

    /// Max individual tiles per monitor before auto-grouping same-app windows
    var maxTilesPerMonitor: Int {
        get { defaults.integer(forKey: "maxTilesPerMonitor").nonZeroOr(6) }
        set { defaults.set(newValue, forKey: "maxTilesPerMonitor") }
    }

    // MARK: - Column/Row sizing for floating mode

    var columnSize: Int {
        get { defaults.integer(forKey: "columnSize").nonZeroOr(128) }
        set { defaults.set(newValue, forKey: "columnSize") }
    }

    var rowSize: Int {
        get { defaults.integer(forKey: "rowSize").nonZeroOr(128) }
        set { defaults.set(newValue, forKey: "rowSize") }
    }

    // MARK: - Float exceptions (apps that should always float)

    var floatExceptions: [String] {
        get { defaults.stringArray(forKey: "floatExceptions") ?? Self.defaultFloatExceptions }
        set { defaults.set(newValue, forKey: "floatExceptions") }
    }

    func shouldFloat(bundleId: String?) -> Bool {
        guard let bundleId else { return false }
        return floatExceptions.contains(bundleId)
    }

    func addFloatException(_ bundleId: String) {
        var list = floatExceptions
        if !list.contains(bundleId) {
            list.append(bundleId)
            floatExceptions = list
        }
    }

    func removeFloatException(_ bundleId: String) {
        var list = floatExceptions
        list.removeAll { $0 == bundleId }
        floatExceptions = list
    }

    private static let defaultFloatExceptions: [String] = [
        "com.apple.systempreferences",
        "com.apple.SystemPreferences",
        "com.apple.Preferences",
        "com.apple.Calculator",
        "com.apple.DigitalColorMeter",
        "com.apple.ScreenCaptureUI",
        "com.apple.screencaptureui",
        "com.apple.ActivityMonitor",
        "com.apple.DiskUtility",
        "com.apple.keychainaccess",
        "com.apple.Dictionary",
        "com.apple.FontBook",
        "com.apple.ScreenSharing",
        "com.apple.stickies",
        "com.apple.PhotoBooth",
    ]
}

private extension Int {
    func nonZeroOr(_ defaultValue: Int) -> Int {
        self == 0 ? defaultValue : self
    }
}
