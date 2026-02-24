// FloatConfigWindow.swift — Configuration window for float exceptions

import AppKit

final class FloatConfigWindow: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private var window: NSWindow?
    private var tableView: NSTableView!
    private var exceptions: [String] = []
    private let settings: Settings

    init(settings: Settings) {
        self.settings = settings
        super.init()
    }

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        exceptions = settings.floatExceptions.sorted()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Float Exceptions"
        window.center()
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        // Label
        let label = NSTextField(labelWithString: "Apps in this list will not be tiled (they float freely).\nClick an app to remove it, or use the buttons below.")
        label.frame = NSRect(x: 16, y: contentView.frame.height - 50, width: contentView.frame.width - 32, height: 36)
        label.autoresizingMask = [.width, .minYMargin]
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        contentView.addSubview(label)

        // Scroll view with table
        let scrollView = NSScrollView(frame: NSRect(x: 16, y: 50, width: contentView.frame.width - 32, height: contentView.frame.height - 106))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let table = NSTableView()
        table.headerView = nil
        table.rowHeight = 22
        table.usesAlternatingRowBackgroundColors = true

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bundleId"))
        col.title = "Bundle Identifier"
        col.width = scrollView.frame.width - 20
        col.resizingMask = .autoresizingMask
        table.addTableColumn(col)

        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(removeSelected)

        scrollView.documentView = table
        contentView.addSubview(scrollView)
        tableView = table

        // Buttons
        let removeBtn = NSButton(title: "Remove Selected", target: self, action: #selector(removeSelected))
        removeBtn.frame = NSRect(x: 16, y: 12, width: 130, height: 28)
        removeBtn.bezelStyle = .rounded
        contentView.addSubview(removeBtn)

        let addBtn = NSButton(title: "Add Current App", target: self, action: #selector(addCurrentApp))
        addBtn.frame = NSRect(x: 154, y: 12, width: 130, height: 28)
        addBtn.bezelStyle = .rounded
        contentView.addSubview(addBtn)

        let addManualBtn = NSButton(title: "Add Manually...", target: self, action: #selector(addManual))
        addManualBtn.frame = NSRect(x: 292, y: 12, width: 115, height: 28)
        addManualBtn.bezelStyle = .rounded
        contentView.addSubview(addManualBtn)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    // MARK: - Table data source

    func numberOfRows(in tableView: NSTableView) -> Int {
        exceptions.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < exceptions.count else { return nil }
        return exceptions[row]
    }

    // MARK: - Actions

    @objc private func removeSelected() {
        let row = tableView.selectedRow
        guard row >= 0 && row < exceptions.count else { return }
        let bundleId = exceptions[row]
        settings.removeFloatException(bundleId)
        exceptions = settings.floatExceptions.sorted()
        tableView.reloadData()
    }

    @objc private func addCurrentApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else { return }
        settings.addFloatException(bundleId)
        exceptions = settings.floatExceptions.sorted()
        tableView.reloadData()
    }

    @objc private func addManual() {
        let alert = NSAlert()
        alert.messageText = "Add Float Exception"
        alert.informativeText = "Enter the bundle identifier (e.g. com.apple.Safari):"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.placeholderString = "com.example.appname"
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let bundleId = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !bundleId.isEmpty {
                settings.addFloatException(bundleId)
                exceptions = settings.floatExceptions.sorted()
                tableView.reloadData()
            }
        }
    }
}
