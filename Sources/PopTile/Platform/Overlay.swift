// Overlay.swift — Visual overlay windows for tiling hints and stack tab bars
// Uses transparent NSWindows positioned over managed windows

import AppKit

// MARK: - Tiling Overlay (active window hint / resize preview)

final class TilingOverlay {
    private var overlayWindow: NSWindow?
    private var borderView: NSView?

    var visible: Bool {
        get { overlayWindow?.isVisible ?? false }
        set { newValue ? show() : hide() }
    }

    var rect: Rect = .zero

    func update(rect: Rect, color: NSColor = .systemBlue, borderWidth: CGFloat = 3.0, borderRadius: CGFloat = 8.0) {
        self.rect = rect
        let screenRect = axToScreen(rect)

        if overlayWindow == nil {
            createWindow()
        }

        guard let overlayWindow, let borderView else { return }

        overlayWindow.setFrame(screenRect, display: true)
        borderView.frame = overlayWindow.contentView!.bounds
        borderView.layer?.borderColor = color.cgColor
        borderView.layer?.borderWidth = borderWidth
        borderView.layer?.cornerRadius = borderRadius
        borderView.layer?.backgroundColor = color.withAlphaComponent(0.1).cgColor
    }

    func show() {
        overlayWindow?.orderFront(nil)
    }

    func hide() {
        overlayWindow?.orderOut(nil)
    }

    private func createWindow() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let view = NSView(frame: window.contentView!.bounds)
        view.wantsLayer = true
        view.layer?.borderColor = NSColor.systemBlue.cgColor
        view.layer?.borderWidth = 3.0
        view.layer?.cornerRadius = 8.0
        view.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
        view.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(view)

        overlayWindow = window
        borderView = view
    }
}

// MARK: - Stack Tab Bar

final class StackTabBar {
    private var tabWindow: NSWindow?
    private var stackView: NSStackView?
    private var tabs: [Entity: NSButton] = [:]
    var active: Entity?
    var activeId: Int = 0
    private var onTabClicked: ((Entity) -> Void)?

    var tabsHeight: CGFloat = 24.0

    func setup(onTabClicked: @escaping (Entity) -> Void) {
        self.onTabClicked = onTabClicked
        createTabWindow()
    }

    func updatePositions(_ rect: Rect) {
        guard let tabWindow else { return }
        let screenRect = axToScreen(Rect(
            x: rect.x,
            y: rect.y - Int(tabsHeight),
            width: rect.width,
            height: Int(tabsHeight)
        ))
        tabWindow.setFrame(screenRect, display: true)
    }

    func setVisible(_ visible: Bool) {
        if visible {
            tabWindow?.orderFront(nil)
        } else {
            tabWindow?.orderOut(nil)
        }
    }

    func clear() {
        stackView?.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tabs.removeAll()
    }

    func addTab(entity: Entity, title: String, icon: NSImage?, isActive: Bool, color: NSColor) {
        guard let stackView else { return }

        let button = NSButton(frame: .zero)
        button.isBordered = false
        button.wantsLayer = true
        // Truncate long titles to keep tabs compact
        button.title = title.count > 25 ? String(title.prefix(22)) + "..." : title
        button.font = .systemFont(ofSize: 11)
        button.lineBreakMode = .byTruncatingTail

        if isActive {
            button.layer?.backgroundColor = color.cgColor
            button.contentTintColor = isDarkColor(color) ? .white : .black
        } else {
            button.layer?.backgroundColor = NSColor(calibratedRed: 0.608, green: 0.557, blue: 0.541, alpha: 1.0).cgColor
            button.contentTintColor = .white
        }

        button.layer?.cornerRadius = 4
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Set image if available
        if let icon {
            let smallIcon = NSImage(size: NSSize(width: 14, height: 14))
            smallIcon.lockFocus()
            icon.draw(in: NSRect(origin: .zero, size: NSSize(width: 14, height: 14)))
            smallIcon.unlockFocus()
            button.image = smallIcon
            button.imagePosition = .imageLeft
            button.imageHugsTitle = true
        }

        button.target = self
        button.tag = entity.index
        button.action = #selector(tabClicked(_:))

        stackView.addArrangedSubview(button)
        tabs[entity] = button
    }

    @objc private func tabClicked(_ sender: NSButton) {
        // Find entity by tag
        for (entity, button) in tabs {
            if button === sender {
                onTabClicked?(entity)
                break
            }
        }
    }

    func destroy() {
        tabWindow?.orderOut(nil)
        tabWindow = nil
        stackView = nil
        tabs.removeAll()
    }

    private func createTabWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: tabsHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = NSColor(calibratedWhite: 0.2, alpha: 0.9)
        window.hasShadow = true
        window.ignoresMouseEvents = false
        // Use normal level so tab bars don't float above other windows
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let sv = NSStackView()
        sv.orientation = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 1
        sv.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(sv)
        if let contentView = window.contentView {
            NSLayoutConstraint.activate([
                sv.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                sv.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                sv.topAnchor.constraint(equalTo: contentView.topAnchor),
                sv.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        }

        tabWindow = window
        stackView = sv
    }

    private func isDarkColor(_ color: NSColor) -> Bool {
        guard let rgb = color.usingColorSpace(.sRGB) else { return false }
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        return luminance < 0.5
    }
}

// MARK: - Coordinate conversion

/// Convert AX coordinates (top-left origin) to NSWindow screen coordinates (bottom-left origin)
func axToScreen(_ rect: Rect) -> NSRect {
    guard let mainScreen = NSScreen.screens.first else {
        return NSRect(x: CGFloat(rect.x), y: CGFloat(rect.y),
                      width: CGFloat(rect.width), height: CGFloat(rect.height))
    }
    let screenHeight = mainScreen.frame.height
    let y = screenHeight - CGFloat(rect.y) - CGFloat(rect.height)
    return NSRect(x: CGFloat(rect.x), y: y,
                  width: CGFloat(rect.width), height: CGFloat(rect.height))
}

/// Convert NSWindow screen coordinates to AX coordinates
func screenToAX(_ rect: NSRect) -> Rect {
    guard let mainScreen = NSScreen.screens.first else {
        return Rect(from: rect)
    }
    let screenHeight = mainScreen.frame.height
    let y = Int(screenHeight - rect.origin.y - rect.size.height)
    return Rect(x: Int(rect.origin.x), y: y,
                width: Int(rect.size.width), height: Int(rect.size.height))
}
