// Overlay.swift — Visual overlay windows for tiling hints and stack tab bars
// Uses transparent NSWindows positioned over managed windows

import AppKit

// MARK: - Custom pasteboard type for tab reordering

extension NSPasteboard.PasteboardType {
    static let tabReorder = NSPasteboard.PasteboardType("com.poptile.tab-reorder")
}

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

// MARK: - Draggable Tab Button

/// NSButton subclass that supports drag-to-reorder within the tab bar.
final class DraggableTabButton: NSButton, NSDraggingSource {
    var tabIndex: Int = 0
    private var mouseDownPoint: NSPoint = .zero
    private var isDragging = false

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .move
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging else { return }
        let current = convert(event.locationInWindow, from: nil)
        let dx = abs(current.x - mouseDownPoint.x)
        guard dx > 5 else { return }
        isDragging = true

        let pb = NSPasteboardItem()
        pb.setString("\(tabIndex)", forType: .tabReorder)

        let dragItem = NSDraggingItem(pasteboardWriter: pb)
        // Create drag image from button appearance
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            layer?.render(in: ctx)
        }
        image.unlockFocus()
        dragItem.setDraggingFrame(bounds, contents: image)

        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            sendAction(action, to: target)
        }
        isDragging = false
    }
}

// MARK: - Tab Bar Drop Target View

/// Content view for the tab bar window that accepts tab reorder drops.
final class TabBarDropView: NSView {
    var onReorder: ((Int, Int) -> Void)?
    var tabCount: Int = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.tabReorder])
    }

    required init?(coder: NSCoder) { nil }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        .move
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pb = sender.draggingPasteboard.pasteboardItems?.first,
              let str = pb.string(forType: .tabReorder),
              let sourceIdx = Int(str) else { return false }

        let dropPoint = convert(sender.draggingLocation, from: nil)
        guard tabCount > 0 else { return false }
        let tabWidth = bounds.width / CGFloat(tabCount)
        let targetIdx = min(tabCount - 1, max(0, Int(dropPoint.x / tabWidth)))

        if sourceIdx != targetIdx {
            onReorder?(sourceIdx, targetIdx)
        }
        return true
    }
}

// MARK: - Stack Tab Bar

final class StackTabBar {
    private var tabWindow: NSWindow?
    private var dropView: TabBarDropView?
    private var stackView: NSStackView?
    private var tabs: [Entity: DraggableTabButton] = [:]
    private var tabOrder: [Entity] = []
    var active: Entity?
    var activeId: Int = 0
    private var onTabClicked: ((Entity) -> Void)?
    var onReorder: ((Int, Int) -> Void)?

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
        tabOrder.removeAll()
        dropView?.tabCount = 0
    }

    func addTab(entity: Entity, title: String, icon: NSImage?, isActive: Bool, color: NSColor) {
        guard let stackView else { return }

        let button = DraggableTabButton(frame: .zero)
        button.tabIndex = tabOrder.count
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
        tabOrder.append(entity)
        dropView?.tabCount = tabOrder.count
    }

    @objc private func tabClicked(_ sender: NSButton) {
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
        dropView = nil
        stackView = nil
        tabs.removeAll()
        tabOrder.removeAll()
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

        // Use TabBarDropView as the content view for drag-and-drop reordering
        let dv = TabBarDropView(frame: NSRect(x: 0, y: 0, width: 200, height: tabsHeight))
        dv.onReorder = { [weak self] from, to in
            self?.onReorder?(from, to)
        }
        window.contentView = dv

        let sv = NSStackView()
        sv.orientation = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 1
        sv.translatesAutoresizingMaskIntoConstraints = false
        dv.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.leadingAnchor.constraint(equalTo: dv.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: dv.trailingAnchor),
            sv.topAnchor.constraint(equalTo: dv.topAnchor),
            sv.bottomAnchor.constraint(equalTo: dv.bottomAnchor),
        ])

        tabWindow = window
        dropView = dv
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
