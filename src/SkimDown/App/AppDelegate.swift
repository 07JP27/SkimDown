import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    let settingsStore = SettingsStore()
    let bookmarkStore = FolderBookmarkStore()
    lazy var windowManager = WindowManager(settingsStore: settingsStore, bookmarkStore: bookmarkStore)
    weak var recentMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = MainMenuBuilder.build(target: self)
        windowManager.restoreOrCreateInitialWindow()
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
        case #selector(toggleSidebar(_:)), #selector(zoomIn(_:)), #selector(zoomOut(_:)), #selector(actualSize(_:)), #selector(themeSystem(_:)), #selector(themeLight(_:)), #selector(themeDark(_:)):
            return controller != nil
        case #selector(swapSidebarPosition(_:)):
            menuItem.title = controller?.sidebarPosition == .right ? "Move Sidebar to Left" : "Move Sidebar to Right"
            return controller != nil
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
        windowManager.activeController?.setTheme(.system)
    }

    @objc func themeLight(_ sender: Any?) {
        windowManager.activeController?.setTheme(.light)
    }

    @objc func themeDark(_ sender: Any?) {
        windowManager.activeController?.setTheme(.dark)
    }
}
