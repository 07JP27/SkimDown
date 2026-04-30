import AppKit

@MainActor
final class WindowManager {
    private let settingsStore: SettingsStore
    private let bookmarkStore: FolderBookmarkStore
    private var controllers: [DocumentWindowController] = []
    private var isTerminating = false

    init(settingsStore: SettingsStore, bookmarkStore: FolderBookmarkStore) {
        self.settingsStore = settingsStore
        self.bookmarkStore = bookmarkStore
    }

    var activeController: DocumentWindowController? {
        NSApp.keyWindow?.windowController as? DocumentWindowController
    }

    func restoreOrCreateInitialWindow() {
        let openStates = settingsStore.openFolderStates
        var restoredAny = false

        for state in openStates {
            guard let url = try? bookmarkStore.resolveBookmarkData(state.bookmark) else {
                continue
            }
            let initialFrame: CGRect? = state.frame == .zero ? nil : state.frame
            let controller = createWindow(initialFrame: initialFrame)
            controller.openFolder(url, bookmarkData: state.bookmark)
            restoredAny = true
        }

        if !openStates.isEmpty {
            // Re-persist (potentially as an empty list) so unresolved bookmarks
            // are dropped from storage even when zero windows were restored.
            // Otherwise the same dead entries would be retried on every launch.
            persistOpenFolderState()
        }

        if restoredAny {
            return
        }

        // Backward-compatible fallback for users upgrading from a build that
        // only tracked the single most-recent folder.
        if let bookmark = settingsStore.lastFolderBookmark,
           let url = try? bookmarkStore.resolveBookmarkData(bookmark) {
            let controller = createWindow()
            controller.openFolder(url, bookmarkData: bookmark)
            return
        }

        createWindow()
    }

    @discardableResult
    func createWindow(initialFrame: CGRect? = nil) -> DocumentWindowController {
        let controller = DocumentWindowController(settingsStore: settingsStore, bookmarkStore: bookmarkStore, windowManager: self)
        controllers.append(controller)
        if let initialFrame, let window = controller.window {
            // Apply the persisted frame before the window is shown so that
            // `placeWindowOnActiveScreenIfNeeded()` can use it to decide
            // whether the saved position is still on-screen.
            window.setFrame(initialFrame, display: false)
        }
        controller.showWindow(nil)
        present(controller, preserveOnScreenFrame: initialFrame != nil)
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
        // While the app is terminating, AppKit closes every window in turn.
        // We must not let those closures shrink the persisted open-folder list
        // (otherwise the next launch only restores the last surviving window).
        // The snapshot was already written in `prepareForTermination()`.
        guard !isTerminating else {
            return
        }
        persistOpenFolderState()
    }

    func persistOpenFolderState() {
        settingsStore.openFolderStates = controllers.compactMap { controller in
            guard let bookmark = controller.currentFolderBookmarkData,
                  let frame = controller.window?.frame else {
                return nil
            }
            return OpenFolderState(bookmark: bookmark, frame: frame)
        }
    }

    /// Capture the current set of open folders and freeze the persisted state
    /// so that the in-flight window closures during termination don't clobber it.
    func prepareForTermination() {
        guard !isTerminating else {
            return
        }
        persistOpenFolderState()
        isTerminating = true
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Could not open folder"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func present(_ controller: DocumentWindowController, preserveOnScreenFrame: Bool = false) {
        guard let window = controller.window else {
            return
        }
        controller.placeWindowOnActiveScreenIfNeeded(preserveOnScreenFrame: preserveOnScreenFrame)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
}
