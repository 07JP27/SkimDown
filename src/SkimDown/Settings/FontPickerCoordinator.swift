import AppKit

@MainActor
final class FontPickerCoordinator: NSObject {
    private weak var viewModel: PreferencesViewModel?

    init(viewModel: PreferencesViewModel) {
        self.viewModel = viewModel
    }

    func showFontPanel(in window: NSWindow?) {
        let fontManager = NSFontManager.shared
        fontManager.target = self
        fontManager.action = #selector(changeFont(_:))

        let currentFont: NSFont
        if let familyName = viewModel?.fontFamily,
           let font = NSFont(name: familyName, size: viewModel?.fontSize ?? 16) {
            currentFont = font
        } else {
            currentFont = NSFont.systemFont(ofSize: viewModel?.fontSize ?? 16)
        }
        fontManager.setSelectedFont(currentFont, isMultiple: false)

        if let window {
            window.makeFirstResponder(window.contentView)
        }
        fontManager.orderFrontFontPanel(self)
    }

    @objc func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else {
            return
        }
        let baseFont = NSFont.systemFont(ofSize: viewModel?.fontSize ?? 16)
        let newFont = fontManager.convert(baseFont)
        let familyName = newFont.fontName

        if familyName == NSFont.systemFont(ofSize: newFont.pointSize).fontName {
            viewModel?.fontFamily = nil
        } else {
            viewModel?.fontFamily = familyName
        }
    }
}
