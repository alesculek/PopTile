// HotkeyManager.swift — Global keyboard shortcuts via CGEventTap
// Intercepts key events and dispatches to tiling actions

import AppKit
import Carbon

/// A registered hotkey
struct Hotkey: Hashable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers.rawValue & Self.significantMask)
    }

    static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        lhs.keyCode == rhs.keyCode &&
        (lhs.modifiers.rawValue & significantMask) == (rhs.modifiers.rawValue & significantMask)
    }

    /// Mask for modifier keys we care about
    private static let significantMask = NSEvent.ModifierFlags([.control, .option, .shift, .command]).rawValue
}

final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var bindings: [Hotkey: () -> Void] = [:]

    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

            // Handle tap being disabled by system timeout
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            if type == .keyDown {
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let flags = event.flags

                var mods = NSEvent.ModifierFlags()
                if flags.contains(.maskControl) { mods.insert(.control) }
                if flags.contains(.maskAlternate) { mods.insert(.option) }
                if flags.contains(.maskShift) { mods.insert(.shift) }
                if flags.contains(.maskCommand) { mods.insert(.command) }

                let hotkey = Hotkey(keyCode: keyCode, modifiers: mods)

                if let action = manager.bindings[hotkey] {
                    DispatchQueue.main.async { action() }
                    return nil // Consume the event
                }
            }

            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: refcon
        ) else {
            log(" ERROR: Failed to create event tap. Check Input Monitoring permission.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        log(" Event tap started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func register(_ keyCode: UInt16, _ modifiers: NSEvent.ModifierFlags, _ action: @escaping () -> Void) {
        let hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers)
        bindings[hotkey] = action
    }

    func clearBindings() {
        bindings.removeAll()
    }
}

// MARK: - Key codes (Carbon virtual key codes)

enum KeyCode {
    static let returnKey: UInt16 = 36
    static let escape: UInt16 = 53
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
    static let h: UInt16 = 4
    static let j: UInt16 = 38
    static let k: UInt16 = 40
    static let l: UInt16 = 37
    static let o: UInt16 = 31
    static let s: UInt16 = 1
    static let g: UInt16 = 5
    static let t: UInt16 = 17
    static let tab: UInt16 = 48
    static let leftBracket: UInt16 = 33
    static let rightBracket: UInt16 = 30
}
