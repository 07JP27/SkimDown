import AppKit

@MainActor
protocol EmptyStateViewDelegate: AnyObject {
    func emptyStateViewDidRequestOpenFolder(_ view: EmptyStateView)
}

@MainActor
final class EmptyStateView: NSView {
    enum State {
        case initial
        case noMarkdown
    }

    weak var delegate: EmptyStateViewDelegate?

    private let label = NSTextField(labelWithString: "")
    private let button = NSButton(title: "Open Folder...", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        button.target = self
        button.action = #selector(openFolder)
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [label, button])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        configure(.initial)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(_ state: State) {
        switch state {
        case .initial:
            label.stringValue = ""
            label.isHidden = true
            button.title = "Open Folder..."
        case .noMarkdown:
            label.stringValue = "No Markdown files found"
            label.isHidden = false
            button.title = "Open Another Folder..."
        }
    }

    @objc private func openFolder() {
        delegate?.emptyStateViewDidRequestOpenFolder(self)
    }
}

