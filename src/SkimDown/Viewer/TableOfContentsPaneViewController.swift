import AppKit

@MainActor
protocol TableOfContentsPaneViewControllerDelegate: AnyObject {
    func tableOfContentsPaneViewController(_ controller: TableOfContentsPaneViewController, didSelect item: TableOfContentsItem)
}

@MainActor
final class TableOfContentsPaneViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private enum Metrics {
        static let topPadding: CGFloat = 12
        static let horizontalPadding: CGFloat = 14
        static let listHorizontalPadding: CGFloat = 8
        static let titleToListSpacing: CGFloat = 8
        static let bottomPadding: CGFloat = 10
        static let emptyContentHeight: CGFloat = 48
    }

    weak var delegate: TableOfContentsPaneViewControllerDelegate?

    private let titleLabel = NSTextField(labelWithString: "Contents")
    private let emptyLabel = NSTextField(labelWithString: "No headings")
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var items: [TableOfContentsItem] = []
    private var activeHeadingID: String?
    private var isProgrammaticSelection = false
    private var minimumHeadingLevel = 1

    var preferredPaneHeight: CGFloat {
        let rowCount = items.count
        let listHeight: CGFloat
        if rowCount == 0 {
            listHeight = Metrics.emptyContentHeight
        } else {
            listHeight = CGFloat(rowCount) * tableView.rowHeight
                + CGFloat(max(0, rowCount - 1)) * tableView.intercellSpacing.height
        }

        return Metrics.topPadding
            + titleLabel.intrinsicContentSize.height
            + Metrics.titleToListSpacing
            + listHeight
            + Metrics.bottomPadding
    }

    static func resolvedPaneHeight(preferredHeight: CGFloat, availableHeight: CGFloat) -> CGFloat {
        guard availableHeight > 0 else {
            return preferredHeight
        }
        return min(preferredHeight, availableHeight)
    }

    override func loadView() {
        let rootView = NSVisualEffectView()
        rootView.material = .sidebar
        rootView.blendingMode = .withinWindow
        rootView.state = .active
        rootView.wantsLayer = true
        rootView.layer?.cornerRadius = 12
        rootView.layer?.borderWidth = 1
        rootView.layer?.masksToBounds = true
        view = rootView
        updatePanelChrome()

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
        tableView.selectionHighlightStyle = .none
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
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.horizontalPadding),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.horizontalPadding),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: Metrics.topPadding),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.listHorizontalPadding),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.listHorizontalPadding),
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Metrics.titleToListSpacing),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Metrics.bottomPadding),

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

    private func updatePanelChrome() {
        view.layer?.borderColor = NSColor.separatorColor
            .withAlphaComponent(0.28)
            .cgColor
    }
}

private final class TableOfContentsCellView: NSTableCellView {
    private static let activeBackgroundColor = NSColor(
        calibratedRed: 0.04,
        green: 0.40,
        blue: 0.84,
        alpha: 1
    )

    private let titleLabel = NSTextField(labelWithString: "")
    private var leadingConstraint: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true

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
        titleLabel.textColor = isActive ? .white : .labelColor
        layer?.backgroundColor = isActive
            ? Self.activeBackgroundColor.cgColor
            : NSColor.clear.cgColor
        leadingConstraint.constant = 8 + indentation
    }
}
