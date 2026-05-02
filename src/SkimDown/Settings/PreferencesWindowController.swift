import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController {
    static let shared = PreferencesWindowController()

    private var windowController: NSWindowController?
    private var viewModel: PreferencesViewModel?
    private var fontPickerCoordinator: FontPickerCoordinator?

    private init() {}

    func showWindow(settingsStore: SettingsStore, themeStore: ThemeStore) {
        if let existingWindow = windowController?.window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            viewModel?.reloadFromStore()
            return
        }

        let vm = PreferencesViewModel(settingsStore: settingsStore, themeStore: themeStore)
        let coordinator = FontPickerCoordinator(viewModel: vm)
        let preferencesView = PreferencesView(viewModel: vm, fontPickerCoordinator: coordinator)

        let hostingController = NSHostingController(rootView: preferencesView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()

        let controller = NSWindowController(window: window)
        controller.showWindow(nil)

        self.windowController = controller
        self.viewModel = vm
        self.fontPickerCoordinator = coordinator
    }
}
