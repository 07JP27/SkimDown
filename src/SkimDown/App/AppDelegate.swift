import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    let settingsStore = SettingsStore()
    let bookmarkStore = FolderBookmarkStore()
    let colorSchemeStore = ColorSchemeStore()
    lazy var windowManager = WindowManager(settingsStore: settingsStore, bookmarkStore: bookmarkStore, colorSchemeStore: colorSchemeStore)
    weak var recentMenu: NSMenu?
    weak var themeMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Load themes before restoring windows because a custom theme may be selected at launch.
        colorSchemeStore.reload()
        settingsStore.theme = colorSchemeStore.normalizedTheme(settingsStore.theme)
        NSApp.mainMenu = MainMenuBuilder.build(target: self)

        if let fileURL = Self.fileURLFromArguments() {
            windowManager.openFile(fileURL)
        } else if let folderURL = Self.folderURLFromArguments() {
            windowManager.openFolder(folderURL)
        } else {
            windowManager.restoreOrCreateInitialWindow()
        }
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        var isFirstFile = true
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                continue
            }
            if isDirectory.boolValue {
                windowManager.openFolder(url)
            } else if url.skimdownIsMarkdownFile {
                windowManager.openFile(url, preferExistingEmptyWindow: isFirstFile)
                isFirstFile = false
            }
        }
    }

    /// Returns a folder URL from command-line arguments, if a valid directory
    /// path was supplied. The first argument after the executable is treated as
    /// the target folder path. When launched from a terminal without arguments,
    /// the current working directory is used.
    private static func folderURLFromArguments() -> URL? {
        let args = CommandLine.arguments
        if args.count > 1 {
            let path = (args[1] as NSString).standardizingPath
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                return nil
            }
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        // When launched from a terminal without arguments, open the current
        // working directory. isatty(STDIN_FILENO) distinguishes terminal
        // launches from Finder/Dock launches where stdin is not a TTY.
        guard isatty(STDIN_FILENO) != 0 else { return nil }
        let cwd = FileManager.default.currentDirectoryPath
        guard cwd != "/" else { return nil }
        return URL(fileURLWithPath: cwd, isDirectory: true)
    }

    /// Returns a markdown file URL from command-line arguments, if the first
    /// argument after the executable is a path to a markdown file.
    private static func fileURLFromArguments() -> URL? {
        let args = CommandLine.arguments
        guard args.count > 1 else {
            return nil
        }
        let path = (args[1] as NSString).standardizingPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return nil
        }
        let url = URL(fileURLWithPath: path, isDirectory: false)
        return url.skimdownIsMarkdownFile ? url : nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        windowManager.prepareForTermination()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowManager.prepareForTermination()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            windowManager.bringAllWindowsToFront()
        } else {
            windowManager.createWindow()
        }
        return true
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === themeMenu {
            MainMenuBuilder.populateThemeMenu(
                menu,
                target: self,
                customThemes: colorSchemeStore.schemes,
                currentTheme: settingsStore.theme
            )
            return
        }

        guard menu === recentMenu else {
            return
        }

        menu.removeAllItems()
        for bookmark in settingsStore.recentFolderBookmarks {
            guard let resolvedURL = try? bookmarkStore.resolveBookmarkData(bookmark) else {
                continue
            }
            let item = NSMenuItem(title: resolvedURL.skimdownDisplayName, action: #selector(openRecentFolder(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = bookmark
            menu.addItem(item)
        }

        if menu.items.isEmpty {
            let item = NSMenuItem(title: "No Recent Folders", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let controller = windowManager.activeController
        switch menuItem.action {
        case #selector(revealInFinder(_:)), #selector(copyFilePath(_:)):
            return controller?.selectedFileURL != nil
        case #selector(copy(_:)), #selector(selectAll(_:)), #selector(showFind(_:)), #selector(findNext(_:)), #selector(findPrevious(_:)), #selector(useSelectionForFind(_:)):
            return controller?.selectedFileURL != nil
        case #selector(toggleSidebar(_:)):
            return controller != nil && !controller!.isSingleFile
        case #selector(toggleTableOfContents(_:)):
            menuItem.state = controller?.isTableOfContentsVisible == true ? .on : .off
            return controller?.selectedFileURL != nil
        case #selector(swapSidebarPosition(_:)):
            menuItem.title = controller?.sidebarPosition == .right ? "Move Sidebar to Left" : "Move Sidebar to Right"
            return controller != nil && !controller!.isSingleFile
        case #selector(zoomIn(_:)), #selector(zoomOut(_:)), #selector(actualSize(_:)):
            return controller != nil
        case #selector(themeSystem(_:)), #selector(themeLight(_:)), #selector(themeDark(_:)), #selector(themeCustom(_:)):
            return true
        case #selector(openThemesFolder(_:)), #selector(reloadThemes(_:)):
            return true
        default:
            return true
        }
    }

    @objc func newWindow(_ sender: Any?) {
        windowManager.createWindow()
    }

    @objc func openFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Folder"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }
            Task { @MainActor in
                self?.windowManager.openFolder(url)
            }
        }
    }

    @objc func openFile(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "markdown")
        ].compactMap { $0 }
        panel.prompt = "Open File"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }
            Task { @MainActor in
                self?.windowManager.openFile(url)
            }
        }
    }

    @objc func openRecentFolder(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Data else {
            return
        }
        windowManager.openBookmarkData(bookmark)
    }

    @objc func revealInFinder(_ sender: Any?) {
        windowManager.activeController?.revealInFinder()
    }

    @objc func copyFilePath(_ sender: Any?) {
        windowManager.activeController?.copyFilePath()
    }

    @objc func copy(_ sender: Any?) {
        windowManager.activeController?.copySelection()
    }

    @objc func selectAll(_ sender: Any?) {
        windowManager.activeController?.selectAllContent()
    }

    @objc func showFind(_ sender: Any?) {
        windowManager.activeController?.showFind()
    }

    @objc func findNext(_ sender: Any?) {
        windowManager.activeController?.findNext()
    }

    @objc func findPrevious(_ sender: Any?) {
        windowManager.activeController?.findPrevious()
    }

    @objc func useSelectionForFind(_ sender: Any?) {
        windowManager.activeController?.useSelectionForFind()
    }

    @objc func toggleSidebar(_ sender: Any?) {
        windowManager.activeController?.toggleSidebar()
    }

    @objc func toggleTableOfContents(_ sender: Any?) {
        windowManager.activeController?.toggleTableOfContents()
    }

    @objc func swapSidebarPosition(_ sender: Any?) {
        windowManager.activeController?.swapSidebarPosition()
    }

    @objc func zoomIn(_ sender: Any?) {
        windowManager.activeController?.changeFontSize(by: 1)
    }

    @objc func zoomOut(_ sender: Any?) {
        windowManager.activeController?.changeFontSize(by: -1)
    }

    @objc func actualSize(_ sender: Any?) {
        windowManager.activeController?.setFontSize(16)
    }

    @objc func themeSystem(_ sender: Any?) {
        windowManager.applyThemeToAllWindows(.system)
    }

    @objc func themeLight(_ sender: Any?) {
        windowManager.applyThemeToAllWindows(.light)
    }

    @objc func themeDark(_ sender: Any?) {
        windowManager.applyThemeToAllWindows(.dark)
    }

    @objc func themeCustom(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let id = menuItem.representedObject as? String else {
            return
        }
                // Prevent selecting a theme that has disappeared from the store.
        guard colorSchemeStore.scheme(id: id) != nil else {
            NSSound.beep()
            return
        }
        windowManager.applyThemeToAllWindows(.custom(id: id))
    }

    @objc func openThemesFolder(_ sender: Any?) {
        colorSchemeStore.ensureDirectoryExists()
        NSWorkspace.shared.open(colorSchemeStore.directoryURL)
    }

    @objc func reloadThemes(_ sender: Any?) {
        colorSchemeStore.reload()
        // Fall back to System across all windows if the selected theme was removed.
        let normalizedTheme = colorSchemeStore.normalizedTheme(settingsStore.theme)
        if normalizedTheme != settingsStore.theme {
            windowManager.applyThemeToAllWindows(normalizedTheme)
        } else {
            windowManager.reapplyCurrentThemeToAllWindows()
        }
    }
}
