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
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private var treeItems: [MarkdownTreeItem] = []
    private var expandedPaths: Set<String> = []

    override func loadView() {
        let rootView = FolderDropVisualEffectView()
        rootView.material = .sidebar
        rootView.blendingMode = .behindWindow
        rootView.state = .active
        rootView.onFolderDropped = { [weak self] url in
            self?.onFolderDropped?(url)
        }
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
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            headerView.heightAnchor.constraint(equalToConstant: 58),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),

            countLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            countLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
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
        guard let fileURL else {
            outlineView.deselectAll(nil)
            return
        }

        for row in 0..<outlineView.numberOfRows {
            guard let item = outlineView.item(atRow: row) as? MarkdownTreeItem else {
                continue
            }
            if item.fileURL?.skimdownCanonicalFileURL == fileURL.skimdownCanonicalFileURL {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                outlineView.scrollRowToVisible(row)
                return
            }
        }
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
        textField.textColor = item.isDirectory ? .secondaryLabelColor : .labelColor
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0,
              let item = outlineView.item(atRow: row) as? MarkdownTreeItem,
              let fileURL = item.fileURL else {
            return
        }
        delegate?.sidebarViewController(self, didSelectFile: fileURL)
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        updateExpandedPathsFromOutline()
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
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
        for item in treeItems {
            restoreExpandedItems(item)
        }
    }

    private func restoreExpandedItems(_ item: MarkdownTreeItem) {
        if expandedPaths.contains(item.relativePath) {
            outlineView.expandItem(item)
        }
        item.children.forEach(restoreExpandedItems)
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
}
