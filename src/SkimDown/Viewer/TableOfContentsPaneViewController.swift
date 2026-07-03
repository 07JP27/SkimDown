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
        static let scrollFittingAllowance: CGFloat = 10
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
    private var backgroundColorOverride: NSColor?

    var preferredPaneHeight: CGFloat {
        let rowCount = items.count
        let listHeight = Self.preferredListHeight(
            rowCount: rowCount,
            rowHeight: tableView.rowHeight,
            intercellSpacing: tableView.intercellSpacing.height
        )

        return Metrics.topPadding
            + titleLabel.intrinsicContentSize.height
            + Metrics.titleToListSpacing
            + listHeight
            + Metrics.bottomPadding
    }

    static func preferredListHeight(rowCount: Int, rowHeight: CGFloat, intercellSpacing: CGFloat) -> CGFloat {
        guard rowCount > 0 else {
            return Metrics.emptyContentHeight
        }
        return CGFloat(rowCount) * rowHeight
            + CGFloat(max(0, rowCount - 1)) * intercellSpacing
            + Metrics.scrollFittingAllowance
    }

    static func resolvedPaneHeight(preferredHeight: CGFloat, availableHeight: CGFloat) -> CGFloat {
        guard availableHeight != 0 else {
            return preferredHeight
        }
        return max(0, min(preferredHeight, availableHeight))
    }

    static func nativeBackgroundColor(from value: String) -> NSColor? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "#" else {
            return nil
        }
        let hex = trimmed.dropFirst()
        guard [3, 4, 6, 8].contains(hex.count),
              hex.allSatisfy(\.isHexDigit) else {
            return nil
        }

        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8

        switch hex.count {
        case 3, 4:
            let values = hex.compactMap { character in
                UInt8(String(repeating: String(character), count: 2), radix: 16)
            }
            guard values.count == hex.count else {
                return nil
            }
            red = values[0]
            green = values[1]
            blue = values[2]
            alpha = values.count == 4 ? values[3] : 255
        case 6, 8:
            let text = String(hex)
            guard let parsedRed = Self.hexByte(text, offset: 0),
                  let parsedGreen = Self.hexByte(text, offset: 2),
                  let parsedBlue = Self.hexByte(text, offset: 4) else {
                return nil
            }
            red = parsedRed
            green = parsedGreen
            blue = parsedBlue
            if hex.count == 8 {
                guard let parsedAlpha = Self.hexByte(text, offset: 6) else {
                    return nil
                }
                alpha = parsedAlpha
            } else {
                alpha = 255
            }
        default:
            return nil
        }

        return NSColor(
            calibratedRed: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: CGFloat(alpha) / 255
        )
    }

    override func loadView() {
        let rootView = TableOfContentsPaneBackgroundView()
        rootView.wantsLayer = true
        rootView.layer?.cornerRadius = 10
        rootView.layer?.borderWidth = 0
        rootView.layer?.masksToBounds = true
        rootView.backgroundColorOverride = backgroundColorOverride
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

    func setBackgroundColor(_ color: NSColor?) {
        backgroundColorOverride = color
        guard isViewLoaded,
              let backgroundView = view as? TableOfContentsPaneBackgroundView else {
            return
        }
        backgroundView.backgroundColorOverride = color
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

    private static func hexByte(_ text: String, offset: Int) -> UInt8? {
        let start = text.index(text.startIndex, offsetBy: offset)
        let end = text.index(start, offsetBy: 2)
        return UInt8(text[start..<end], radix: 16)
    }

}

private final class TableOfContentsPaneBackgroundView: NSView {
    var backgroundColorOverride: NSColor? {
        didSet {
            updateBackgroundColor()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        updateBackgroundColor()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackgroundColor()
    }

    private func updateBackgroundColor() {
        layer?.backgroundColor = (backgroundColorOverride ?? backgroundColor(for: effectiveAppearance)).cgColor
    }

    private func backgroundColor(for appearance: NSAppearance) -> NSColor {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(calibratedRed: 9.0 / 255.0, green: 11.0 / 255.0, blue: 13.0 / 255.0, alpha: 1)
            : NSColor(calibratedRed: 240.0 / 255.0, green: 240.0 / 255.0, blue: 242.0 / 255.0, alpha: 1)
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
