import AppKit

@MainActor
protocol SearchBarViewDelegate: AnyObject {
    func searchBarView(_ searchBarView: SearchBarView, didChangeQuery query: String, caseSensitive: Bool)
    func searchBarViewDidRequestNext(_ searchBarView: SearchBarView)
    func searchBarViewDidRequestPrevious(_ searchBarView: SearchBarView)
    func searchBarViewDidRequestClose(_ searchBarView: SearchBarView)
}

@MainActor
final class SearchBarView: NSView, NSSearchFieldDelegate {
    weak var delegate: SearchBarViewDelegate?

    private let searchField = NSSearchField()
    private let countLabel = NSTextField(labelWithString: "0/0")
    private let caseButton = NSButton(checkboxWithTitle: "Case", target: nil, action: nil)
    private let previousButton = NSButton(title: "Prev", target: nil, action: nil)
    private let nextButton = NSButton(title: "Next", target: nil, action: nil)
    private let closeButton = NSButton(title: "Done", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchAction)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        [countLabel, caseButton, previousButton, nextButton, closeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = .secondaryLabelColor
        caseButton.target = self
        caseButton.action = #selector(caseChanged)
        previousButton.target = self
        previousButton.action = #selector(previous)
        nextButton.target = self
        nextButton.action = #selector(next)
        closeButton.target = self
        closeButton.action = #selector(close)

        let stack = NSStackView(views: [searchField, countLabel, caseButton, previousButton, nextButton, closeButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    var query: String {
        searchField.stringValue
    }

    var isCaseSensitive: Bool {
        get { caseButton.state == .on }
        set { caseButton.state = newValue ? .on : .off }
    }

    func focus() {
        window?.makeFirstResponder(searchField)
    }

    func setResult(_ result: SearchResult) {
        countLabel.stringValue = result.count == 0 ? "0/0" : "\(result.index)/\(result.count)"
    }

    func setQuery(_ query: String) {
        searchField.stringValue = query
        delegate?.searchBarView(self, didChangeQuery: query, caseSensitive: isCaseSensitive)
    }

    func controlTextDidChange(_ obj: Notification) {
        delegate?.searchBarView(self, didChangeQuery: query, caseSensitive: isCaseSensitive)
    }

    @objc private func searchAction() {
        delegate?.searchBarViewDidRequestNext(self)
    }

    @objc private func caseChanged() {
        delegate?.searchBarView(self, didChangeQuery: query, caseSensitive: isCaseSensitive)
    }

    @objc private func previous() {
        delegate?.searchBarViewDidRequestPrevious(self)
    }

    @objc private func next() {
        delegate?.searchBarViewDidRequestNext(self)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    @objc private func close() {
        delegate?.searchBarViewDidRequestClose(self)
    }
}
