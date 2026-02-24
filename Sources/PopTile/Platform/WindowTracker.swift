// WindowTracker.swift — Tracks all windows and observes events
// Uses AXObserver + NSWorkspace to detect window creation/destruction/focus changes

import AppKit
import ApplicationServices

final class WindowTracker {
    weak var engine: Engine?
    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []

    init(engine: Engine) {
        self.engine = engine
    }

    func start() {
        // Observe app launches and terminations
        let nc = NSWorkspace.shared.notificationCenter

        workspaceObservers.append(nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] notif in
            if let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.appLaunched(app)
            }
        })

        workspaceObservers.append(nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notif in
            if let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.appTerminated(app)
            }
        })

        workspaceObservers.append(nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notif in
            if let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.appActivated(app)
            }
        })

        // Scan all currently running apps
        for app in NSWorkspace.shared.runningApplications {
            if app.activationPolicy == .regular {
                setupObserver(for: app)
                discoverWindows(for: app)
            }
        }
    }

    func stop() {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()

        for (_, observer) in observers {
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                                 AXObserverGetRunLoopSource(observer),
                                 .defaultMode)
        }
        observers.removeAll()
    }

    // MARK: - App lifecycle

    private func appLaunched(_ app: NSRunningApplication) {
        guard app.activationPolicy == .regular else { return }
        // Delay slightly to allow windows to be created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupObserver(for: app)
            self?.discoverWindows(for: app)
        }
    }

    private func appTerminated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        removeObserver(for: pid)
        engine?.removeWindowsForApp(pid)
    }

    private func appActivated(_ app: NSRunningApplication) {
        // Re-check focused window
        DispatchQueue.main.async { [weak self] in
            self?.engine?.onFocusChanged()
        }
    }

    // MARK: - AXObserver setup

    private func setupObserver(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard observers[pid] == nil else { return }

        var observer: AXObserver?
        let callback: AXObserverCallback = { observer, element, notification, refcon in
            guard let refcon else { return }
            let tracker = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            let notif = notification as String
            DispatchQueue.main.async {
                tracker.handleNotification(notif, element: element)
            }
        }

        let result = AXObserverCreate(pid, callback, &observer)
        guard result == .success, let observer else { return }

        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let notifications: [String] = [
            kAXWindowCreatedNotification,
            kAXUIElementDestroyedNotification,
            kAXFocusedWindowChangedNotification,
            kAXWindowMovedNotification,
            kAXWindowResizedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification,
        ]

        for notif in notifications {
            AXObserverAddNotification(observer, appElement, notif as CFString, refcon)
        }

        CFRunLoopAddSource(CFRunLoopGetMain(),
                           AXObserverGetRunLoopSource(observer),
                           .defaultMode)

        observers[pid] = observer
    }

    private func removeObserver(for pid: pid_t) {
        if let observer = observers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                                 AXObserverGetRunLoopSource(observer),
                                 .defaultMode)
        }
    }

    // MARK: - Notification handling

    private func handleNotification(_ notification: String, element: AXUIElement) {
        switch notification {
        case kAXWindowCreatedNotification:
            handleWindowCreated(element)
        case kAXUIElementDestroyedNotification:
            handleWindowDestroyed(element)
        case kAXFocusedWindowChangedNotification:
            engine?.onFocusChanged()
        case kAXWindowMovedNotification:
            engine?.onWindowMoved(element)
        case kAXWindowResizedNotification:
            engine?.onWindowResized(element)
        case kAXWindowMiniaturizedNotification:
            engine?.onWindowMinimized(element)
        case kAXWindowDeminiaturizedNotification:
            handleWindowCreated(element) // Re-tile when unminimized
        default:
            break
        }
    }

    private func handleWindowCreated(_ element: AXUIElement) {
        var pidValue: pid_t = 0
        AXUIElementGetPid(element, &pidValue)
        let axWin = AXWindow(element: element, pid: pidValue)
        guard axWin.isStandardWindow() else { return }
        engine?.onWindowCreated(axWin)
    }

    private func handleWindowDestroyed(_ element: AXUIElement) {
        engine?.onWindowDestroyed(element)
    }

    // MARK: - Window discovery

    private func discoverWindows(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        let windows = AXWindow.windowsForApp(pid)
        for axWin in windows {
            engine?.onWindowCreated(axWin)
        }
    }
}
