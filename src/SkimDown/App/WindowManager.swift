import AppKit

@MainActor
final class WindowManager {
    private let settingsStore: SettingsStore
    private let bookmarkStore: FolderBookmarkStore
    private var controllers: [DocumentWindowController] = []

    init(settingsStore: SettingsStore, bookmarkStore: FolderBookmarkStore) {
        self.settingsStore = settingsStore
        self.bookmarkStore = bookmarkStore
    }

    var activeController: DocumentWindowController? {
        NSApp.keyWindow?.windowController as? DocumentWindowController
    }

    func restoreOrCreateInitialWindow() {
        if let bookmark = settingsStore.lastFolderBookmark,
           let url = try? bookmarkStore.resolveBookmarkData(bookmark) {
            let controller = createWindow()
            controller.openFolder(url, bookmarkData: bookmark)
            return
        }

        createWindow()
    }

    @discardableResult
    func createWindow() -> DocumentWindowController {
        let controller = DocumentWindowController(settingsStore: settingsStore, bookmarkStore: bookmarkStore, windowManager: self)
        controllers.append(controller)
        controller.showWindow(nil)
        present(controller)
        return controller
    }

    func bringAllWindowsToFront() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        for controller in controllers {
            present(controller)
        }
    }

    func openFolder(_ folderURL: URL, preferExistingEmptyWindow: Bool = true) {
        let target: DocumentWindowController
        if preferExistingEmptyWindow, let activeController, activeController.isEmpty {
            target = activeController
        } else {
            target = createWindow()
        }
        target.openFolder(folderURL)
    }

    func openBookmarkData(_ bookmarkData: Data) {
        do {
            let url = try bookmarkStore.resolveBookmarkData(bookmarkData)
            let target = activeController?.isEmpty == true ? activeController! : createWindow()
            target.openFolder(url, bookmarkData: bookmarkData)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func controllerDidClose(_ controller: DocumentWindowController) {
        controllers.removeAll { $0 === controller }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Could not open folder"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func present(_ controller: DocumentWindowController) {
        guard let window = controller.window else {
            return
        }
        controller.placeWindowOnActiveScreenIfNeeded()
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
}
