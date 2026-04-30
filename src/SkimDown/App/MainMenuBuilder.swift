import AppKit

@MainActor
enum MainMenuBuilder {
    static func build(target: AppDelegate) -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "SkimDown")
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About SkimDown", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit SkimDown", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(menuItem("New Window", action: #selector(AppDelegate.newWindow(_:)), key: "n", target: target))
        fileMenu.addItem(menuItem("Open Folder...", action: #selector(AppDelegate.openFolder(_:)), key: "o", target: target))

        let openRecent = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        let openRecentMenu = NSMenu(title: "Open Recent")
        openRecentMenu.delegate = target
        target.recentMenu = openRecentMenu
        openRecent.submenu = openRecentMenu
        fileMenu.addItem(openRecent)
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(title: "Close Folder", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(menuItem("Reveal in Finder", action: #selector(AppDelegate.revealInFinder(_:)), key: "", target: target))
        fileMenu.addItem(menuItem("Copy File Path", action: #selector(AppDelegate.copyFilePath(_:)), key: "", target: target))

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(menuItem("Copy", action: #selector(AppDelegate.copy(_:)), key: "c", target: target))
        editMenu.addItem(menuItem("Select All", action: #selector(AppDelegate.selectAll(_:)), key: "a", target: target))
        editMenu.addItem(.separator())

        let findItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        let findMenu = NSMenu(title: "Find")
        findMenu.addItem(menuItem("Find...", action: #selector(AppDelegate.showFind(_:)), key: "f", target: target))
        findMenu.addItem(menuItem("Find Next", action: #selector(AppDelegate.findNext(_:)), key: "g", target: target))
        let previous = menuItem("Find Previous", action: #selector(AppDelegate.findPrevious(_:)), key: "G", target: target)
        previous.keyEquivalentModifierMask = [.command, .shift]
        findMenu.addItem(previous)
        findMenu.addItem(menuItem("Use Selection for Find", action: #selector(AppDelegate.useSelectionForFind(_:)), key: "e", target: target))
        findItem.submenu = findMenu
        editMenu.addItem(findItem)

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(menuItem("Toggle Sidebar", action: #selector(AppDelegate.toggleSidebar(_:)), key: "s", target: target))
        viewMenu.addItem(menuItem("Move Sidebar to Right", action: #selector(AppDelegate.swapSidebarPosition(_:)), key: "", target: target))
        viewMenu.addItem(.separator())

        let zoomItem = NSMenuItem(title: "Zoom", action: nil, keyEquivalent: "")
        let zoomMenu = NSMenu(title: "Zoom")
        zoomMenu.addItem(menuItem("Zoom In", action: #selector(AppDelegate.zoomIn(_:)), key: "+", target: target))
        zoomMenu.addItem(menuItem("Zoom Out", action: #selector(AppDelegate.zoomOut(_:)), key: "-", target: target))
        zoomMenu.addItem(menuItem("Actual Size", action: #selector(AppDelegate.actualSize(_:)), key: "0", target: target))
        zoomItem.submenu = zoomMenu
        viewMenu.addItem(zoomItem)

        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu(title: "Theme")
        themeMenu.addItem(menuItem("System", action: #selector(AppDelegate.themeSystem(_:)), key: "", target: target))
        themeMenu.addItem(menuItem("Light", action: #selector(AppDelegate.themeLight(_:)), key: "", target: target))
        themeMenu.addItem(menuItem("Dark", action: #selector(AppDelegate.themeDark(_:)), key: "", target: target))
        themeItem.submenu = themeMenu
        viewMenu.addItem(themeItem)

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        NSApp.windowsMenu = windowMenu

        return mainMenu
    }

    private static func menuItem(_ title: String, action: Selector, key: String, target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }
}

