// AXWindow.swift — macOS Accessibility API window wrapper
// Wraps AXUIElement for window management operations

import AppKit
import ApplicationServices

/// Hashable key for AXUIElement using CFEqual/CFHash (value semantics).
/// Two AXUIElements referring to the same accessibility object will be equal,
/// even if they are different Objective-C instances (unlike ObjectIdentifier).
struct AXElementKey: Hashable {
    let element: AXUIElement

    func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }

    static func == (lhs: AXElementKey, rhs: AXElementKey) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }
}

final class AXWindow {
    let element: AXUIElement
    let pid: pid_t

    init(element: AXUIElement, pid: pid_t) {
        self.element = element
        self.pid = pid
    }

    // MARK: - Read attributes

    func frame() -> CGRect {
        let pos = position()
        let sz = size()
        return CGRect(origin: pos, size: sz)
    }

    func position() -> CGPoint {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value)
        guard result == .success, let value else { return .zero }
        var point = CGPoint.zero
        AXValueGetValue(value as! AXValue, .cgPoint, &point)
        return point
    }

    func size() -> CGSize {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value)
        guard result == .success, let value else { return .zero }
        var sz = CGSize.zero
        AXValueGetValue(value as! AXValue, .cgSize, &sz)
        return sz
    }

    func title() -> String? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)
        return value as? String
    }

    func role() -> String? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        return value as? String
    }

    func subrole() -> String? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &value)
        return value as? String
    }

    func isMinimized() -> Bool {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value)
        return (value as? Bool) ?? false
    }

    func isFullscreen() -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &value)
        guard result == .success else { return false }
        return (value as? Bool) ?? false
    }

    func isFocused() -> Bool {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXFocusedAttribute as CFString, &value)
        return (value as? Bool) ?? false
    }

    func isResizable() -> Bool {
        var settable: DarwinBoolean = false
        let result = AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &settable)
        guard result == .success else { return true } // Assume resizable if we can't check
        return settable.boolValue
    }

    func isSheet() -> Bool {
        subrole() == "AXSystemDialog" || subrole() == "AXDialog"
    }

    func isStandardWindow() -> Bool {
        let r = role()
        let sr = subrole()
        return r == "AXWindow" && sr == "AXStandardWindow"
    }

    // MARK: - Write attributes

    @discardableResult
    func setFrame(_ rect: CGRect) -> Bool {
        // Set size first, then position, then size again (Rectangle.app technique)
        let r1 = setSize(rect.size)
        let r2 = setPosition(rect.origin)
        let r3 = setSize(rect.size)
        let ok = r2 == .success && (r1 == .success || r3 == .success)
        if !ok {
            log(" AX setFrame failed for pid \(pid): size1=\(r1.rawValue) pos=\(r2.rawValue) size2=\(r3.rawValue)")
        }
        return ok
    }

    @discardableResult
    func setPosition(_ point: CGPoint) -> AXError {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return .failure }
        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    @discardableResult
    func setSize(_ size: CGSize) -> AXError {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else { return .failure }
        return AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    func setMinimized(_ minimized: Bool) {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, minimized as CFBoolean)
    }

    // MARK: - Actions

    func raise() {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    func focus() {
        // Activate the owning application first
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, kAXFocusedApplicationAttribute as CFString, element)
        // Then set this window as the main/focused window
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    func close() {
        var closeButton: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXCloseButtonAttribute as CFString, &closeButton)
        if let closeButton = closeButton {
            AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString)
        }
    }

    // MARK: - Validation

    func isValid() -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        return result == .success
    }

    // MARK: - App info

    func appIcon() -> NSImage? {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return app.icon
    }

    func appName() -> String? {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return app.localizedName
    }

    // MARK: - Static helpers

    /// Get all windows for a given application PID
    static func windowsForApp(_ pid: pid_t) -> [AXWindow] {
        let app = AXUIElementCreateApplication(pid)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windowArray = value as? [AXUIElement] else { return [] }

        return windowArray.map { AXWindow(element: $0, pid: pid) }
            .filter { $0.isStandardWindow() }
    }

    /// Get the focused window of the frontmost application
    static func focusedWindow() -> AXWindow? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier
        let app = AXUIElementCreateApplication(pid)

        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success, let windowElement = value else { return nil }

        return AXWindow(element: windowElement as! AXUIElement, pid: pid)
    }
}
