import AppKit

@MainActor
protocol SidebarViewControllerDelegate: AnyObject {
    func sidebarViewController(_ controller: SidebarViewController, didSelectFile fileURL: URL)
    func sidebarViewController(_ controller: SidebarViewController, didChangeExpandedPaths paths: Set<String>)
}

@MainActor
final class SidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    weak var delegate: SidebarViewControllerDelegate?
    var onFolderDropped: ((URL) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    private let separator = NSBox()
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private var treeItems: [MarkdownTreeItem] = []
    private var expandedPaths: Set<String> = []
    private var isProgrammaticSelection = false
    private var isRestoringExpansion = false
    private var pendingSelectedFileURL: URL?

    /// Currently applied custom theme colors (nil = system default).
    private var activeTheme: ThemeDefinition?

    private var rootVisualEffectView: FolderDropVisualEffectView?
    /// Opaque overlay drawn on top of NSVisualEffectView material to show custom theme color.
    private var themeBackgroundView: NSView?

    override func loadView() {
        let rootView = FolderDropVisualEffectView()
        rootView.material = .sidebar
        rootView.blendingMode = .behindWindow
        rootView.state = .active
        rootView.wantsLayer = true
        rootView.onFolderDropped = { [weak self] url in
            self?.onFolderDropped?(url)
        }
        rootVisualEffectView = rootView
        view = rootView

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingMiddle

        countLabel.font = .systemFont(ofSize: 12)
        countLabel.textColor = .secondaryLabelColor

        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)
        headerView.addSubview(countLabel)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Markdown"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.rowHeight = 26
        outlineView.indentationPerLevel = 14
        outlineView.style = .sourceList
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.action = #selector(outlineViewClicked(_:))
        outlineView.allowsEmptySelection = true
        outlineView.allowsMultipleSelection = false
        outlineView.backgroundColor = .clear
        outlineView.selectionHighlightStyle = .regular

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(headerView)
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            headerView.heightAnchor.constraint(equalToConstant: 54),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 4),

            countLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            countLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.topAnchor.constraint(equalTo: headerView.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func update(folderName: String, markdownCount: Int, treeItems: [MarkdownTreeItem], expandedPaths: Set<String>) {
        titleLabel.stringValue = folderName
        countLabel.stringValue = "\(markdownCount) Markdown file\(markdownCount == 1 ? "" : "s")"
        self.treeItems = treeItems
        self.expandedPaths = expandedPaths
        outlineView.reloadData()
        restoreExpandedItems()
    }

    func selectFile(_ fileURL: URL?) {
        pendingSelectedFileURL = nil

        guard let fileURL else {
            outlineView.deselectAll(nil)
            return
        }

        let canonical = fileURL.skimdownCanonicalFileURL

        // Fast path: file is in a currently visible (expanded) row
        if let row = visibleRow(for: canonical) {
            selectRow(row)
            return
        }

        // Slow path: file is inside a collapsed directory — expand ancestors with animation,
        // then select the row once it becomes available via outlineViewItemDidExpand
        guard let item = findTreeItem(matching: canonical, in: treeItems) else {
            return
        }

        var ancestors: [MarkdownTreeItem] = []
        var current: MarkdownTreeItem? = item.parent
        while let ancestor = current {
            ancestors.append(ancestor)
            current = ancestor.parent
        }

        pendingSelectedFileURL = canonical
        for ancestor in ancestors.reversed() {
            outlineView.animator().expandItem(ancestor)
        }
    }

    private func selectRow(_ row: Int) {
        isProgrammaticSelection = true
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        isProgrammaticSelection = false
        outlineView.scrollRowToVisible(row)
    }

    private func applyPendingSelectionIfReady() {
        guard let pendingURL = pendingSelectedFileURL else {
            return
        }
        if let row = visibleRow(for: pendingURL) {
            pendingSelectedFileURL = nil
            selectRow(row)
        }
    }

    private func visibleRow(for canonicalURL: URL) -> Int? {
        for row in 0..<outlineView.numberOfRows {
            guard let item = outlineView.item(atRow: row) as? MarkdownTreeItem else {
                continue
            }
            if item.fileURL?.skimdownCanonicalFileURL == canonicalURL {
                return row
            }
        }
        return nil
    }

    private func findTreeItem(matching canonicalURL: URL, in items: [MarkdownTreeItem]) -> MarkdownTreeItem? {
        for item in items {
            if !item.isDirectory, item.fileURL?.skimdownCanonicalFileURL == canonicalURL {
                return item
            }
            if let found = findTreeItem(matching: canonicalURL, in: item.children) {
                return found
            }
        }
        return nil
    }

    func numberOfChildren(of item: Any?) -> Int {
        guard let item = item as? MarkdownTreeItem else {
            return treeItems.count
        }
        return item.children.count
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        numberOfChildren(of: item)
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? MarkdownTreeItem {
            return item.children[index]
        }
        return treeItems[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let item = item as? MarkdownTreeItem else {
            return false
        }
        return item.isDirectory && !item.children.isEmpty
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let item = item as? MarkdownTreeItem else {
            return false
        }
        return !item.isDirectory
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let item = item as? MarkdownTreeItem else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("MarkdownTreeCell")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = identifier

        let textField: NSTextField
        if let existing = cell.textField {
            textField = existing
        } else {
            textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingMiddle
            textField.font = .systemFont(ofSize: 13)
            cell.addSubview(textField)
            cell.textField = textField
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        textField.stringValue = item.name
        textField.font = .systemFont(ofSize: 13, weight: item.isDirectory ? .medium : .regular)
        if let theme = activeTheme {
            textField.textColor = item.isDirectory
                ? Self.nsColor(from: theme.colors.muted)
                : Self.nsColor(from: theme.colors.fg)
        } else {
            textField.textColor = item.isDirectory ? .secondaryLabelColor : .labelColor
        }
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isProgrammaticSelection else {
            return
        }
        let row = outlineView.selectedRow
        guard row >= 0,
              let item = outlineView.item(atRow: row) as? MarkdownTreeItem,
              let fileURL = item.fileURL else {
            return
        }
        delegate?.sidebarViewController(self, didSelectFile: fileURL)
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        if !isRestoringExpansion {
            updateExpandedPathsFromOutline()
        }
        applyPendingSelectionIfReady()
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard !isRestoringExpansion else {
            return
        }
        updateExpandedPathsFromOutline()
    }

    @objc private func outlineViewClicked(_ sender: Any?) {
        let row = outlineView.clickedRow
        guard row >= 0,
              let item = outlineView.item(atRow: row) as? MarkdownTreeItem,
              item.isDirectory else {
            return
        }
        if outlineView.isItemExpanded(item) {
            outlineView.animator().collapseItem(item)
        } else {
            outlineView.animator().expandItem(item)
        }
    }

    private func restoreExpandedItems() {
        let itemsToExpand = ExpandedPathRestorer.itemsToExpand(in: treeItems, desired: expandedPaths)
        guard !itemsToExpand.isEmpty else {
            return
        }
        isRestoringExpansion = true
        defer { isRestoringExpansion = false }
        for item in itemsToExpand {
            outlineView.expandItem(item)
        }
    }

    private func updateExpandedPathsFromOutline() {
        var paths = Set<String>()
        for row in 0..<outlineView.numberOfRows {
            guard let item = outlineView.item(atRow: row) as? MarkdownTreeItem,
                  item.isDirectory,
                  outlineView.isItemExpanded(item) else {
                continue
            }
            paths.insert(item.relativePath)
        }
        expandedPaths = paths
        delegate?.sidebarViewController(self, didChangeExpandedPaths: paths)
    }

    // MARK: - Theme

    func applyTheme(_ theme: ThemeDefinition?) {
        activeTheme = theme

        if let theme {
            let bgColor = Self.nsColor(from: theme.colors.subtle)
            ensureThemeBackgroundView().layer?.backgroundColor = bgColor.cgColor

            if theme.opacity < 1.0 {
                rootVisualEffectView?.alphaValue = CGFloat(theme.opacity)
            } else {
                rootVisualEffectView?.alphaValue = 1.0
            }
            scrollView.drawsBackground = false
            outlineView.backgroundColor = .clear

            titleLabel.textColor = Self.nsColor(from: theme.colors.fg)
            countLabel.textColor = Self.nsColor(from: theme.colors.muted)
            separator.borderColor = Self.nsColor(from: theme.colors.border)
        } else {
            removeThemeBackgroundView()
            rootVisualEffectView?.material = .sidebar
            rootVisualEffectView?.state = .active
            rootVisualEffectView?.alphaValue = 1.0
            scrollView.drawsBackground = false
            outlineView.backgroundColor = .clear

            titleLabel.textColor = .labelColor
            countLabel.textColor = .secondaryLabelColor
            separator.borderColor = .separatorColor
        }

        outlineView.reloadData()
    }

    private func ensureThemeBackgroundView() -> NSView {
        if let existing = themeBackgroundView { return existing }
        let bgView = NSView()
        bgView.wantsLayer = true
        bgView.translatesAutoresizingMaskIntoConstraints = false
        guard let root = rootVisualEffectView else { return bgView }
        root.addSubview(bgView, positioned: .below, relativeTo: root.subviews.first)
        NSLayoutConstraint.activate([
            bgView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            bgView.topAnchor.constraint(equalTo: root.topAnchor),
            bgView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        themeBackgroundView = bgView
        return bgView
    }

    private func removeThemeBackgroundView() {
        themeBackgroundView?.removeFromSuperview()
        themeBackgroundView = nil
    }

    /// Parses a CSS hex color string (e.g. `#191724`) into an NSColor.
    /// Falls back to `.labelColor` for unsupported formats (rgba, etc.).
    static func nsColor(from css: String) -> NSColor {
        guard css.hasPrefix("#") else {
            return parseRGBA(css) ?? .labelColor
        }
        let hex = String(css.dropFirst())
        guard let value = UInt64(hex, radix: 16) else {
            return .labelColor
        }
        switch hex.count {
        case 3:
            let r = Double((value >> 8) & 0xF) / 15.0
            let g = Double((value >> 4) & 0xF) / 15.0
            let b = Double(value & 0xF) / 15.0
            return NSColor(red: r, green: g, blue: b, alpha: 1)
        case 6:
            let r = Double((value >> 16) & 0xFF) / 255.0
            let g = Double((value >> 8) & 0xFF) / 255.0
            let b = Double(value & 0xFF) / 255.0
            return NSColor(red: r, green: g, blue: b, alpha: 1)
        case 8:
            let r = Double((value >> 24) & 0xFF) / 255.0
            let g = Double((value >> 16) & 0xFF) / 255.0
            let b = Double((value >> 8) & 0xFF) / 255.0
            let a = Double(value & 0xFF) / 255.0
            return NSColor(red: r, green: g, blue: b, alpha: a)
        default:
            return .labelColor
        }
    }

    private static func parseRGBA(_ css: String) -> NSColor? {
        let trimmed = css.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("rgb") else { return nil }
        let inner = trimmed
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 3,
              let r = Double(parts[0]),
              let g = Double(parts[1]),
              let b = Double(parts[2]) else {
            return nil
        }
        let a = parts.count >= 4 ? (Double(parts[3]) ?? 1.0) : 1.0
        return NSColor(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
    }
}
