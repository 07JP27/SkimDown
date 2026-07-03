import AppKit

@MainActor
protocol TableOfContentsPaneViewControllerDelegate: AnyObject {
    func tableOfContentsPaneViewController(_ controller: TableOfContentsPaneViewController, didSelect item: TableOfContentsItem)
}

@MainActor
final class TableOfContentsPaneViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    weak var delegate: TableOfContentsPaneViewControllerDelegate?

    private let titleLabel = NSTextField(labelWithString: "Contents")
    private let emptyLabel = NSTextField(labelWithString: "No headings")
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var items: [TableOfContentsItem] = []
    private var activeHeadingID: String?
    private var isProgrammaticSelection = false
    private var minimumHeadingLevel = 1

    override func loadView() {
        let rootView = NSVisualEffectView()
        rootView.material = .popover
        rootView.blendingMode = .withinWindow
        rootView.state = .active
        rootView.wantsLayer = true
        rootView.layer?.cornerRadius = 14
        rootView.layer?.borderWidth = 1
        rootView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        rootView.layer?.masksToBounds = true
        view = rootView

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.font = .systemFont(ofSize: 12)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("heading"))
        column.title = "Heading"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(emptyLabel)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),

            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 8)
        ])
    }

    func update(items: [TableOfContentsItem]) {
        self.items = items
        minimumHeadingLevel = items.map(\.level).min() ?? 1
        emptyLabel.isHidden = !items.isEmpty
        scrollView.isHidden = items.isEmpty
        tableView.reloadData()
        applyActiveSelection(scrollToRow: false)
    }

    func setActiveHeadingID(_ headingID: String?) {
        let previousHeadingID = activeHeadingID
        guard previousHeadingID != headingID else {
            return
        }
        activeHeadingID = headingID
        applyActiveSelection(scrollToRow: true)
        reloadRows(matching: [previousHeadingID, headingID])
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard items.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("TableOfContentsCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? TableOfContentsCellView ?? TableOfContentsCellView()
        cell.identifier = identifier
        let item = items[row]
        cell.configure(
            item: item,
            indentation: CGFloat(max(0, item.level - minimumHeadingLevel)) * 12,
            isActive: item.id == activeHeadingID
        )
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isProgrammaticSelection else {
            return
        }

        let row = tableView.selectedRow
        guard items.indices.contains(row) else {
            return
        }
        delegate?.tableOfContentsPaneViewController(self, didSelect: items[row])
    }

    private func applyActiveSelection(scrollToRow: Bool) {
        guard isViewLoaded else {
            return
        }

        isProgrammaticSelection = true
        defer { isProgrammaticSelection = false }

        guard let activeHeadingID,
              let row = items.firstIndex(where: { $0.id == activeHeadingID }) else {
            tableView.deselectAll(nil)
            return
        }

        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        if scrollToRow {
            tableView.scrollRowToVisible(row)
        }
    }

    private func reloadRows(matching headingIDs: [String?]) {
        let rows = headingIDs.compactMap { headingID in
            headingID.flatMap { id in items.firstIndex(where: { $0.id == id }) }
        }
        guard !rows.isEmpty else {
            return
        }
        tableView.reloadData(forRowIndexes: IndexSet(rows), columnIndexes: IndexSet(integer: 0))
    }
}

private final class TableOfContentsCellView: NSTableCellView {
    private let titleLabel = NSTextField(labelWithString: "")
    private var leadingConstraint: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(titleLabel)
        textField = titleLabel

        leadingConstraint = titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
        NSLayoutConstraint.activate([
            leadingConstraint,
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(item: TableOfContentsItem, indentation: CGFloat, isActive: Bool) {
        titleLabel.stringValue = item.title
        titleLabel.font = .systemFont(ofSize: 12, weight: isActive ? .semibold : .regular)
        titleLabel.textColor = isActive ? .controlAccentColor : .labelColor
        leadingConstraint.constant = 8 + indentation
    }
}
