import AppKit

@MainActor
final class DocumentWindowController: NSWindowController, NSWindowDelegate, SidebarViewControllerDelegate, EmptyStateViewDelegate, MarkdownWebViewDelegate, SearchBarViewDelegate {
    private let settingsStore: SettingsStore
    private let bookmarkStore: SecurityScopedBookmarkStore
    private weak var windowManager: WindowManager?

    private let splitViewController = NSSplitViewController()
    private let sidebarViewController = SidebarViewController()
    private let documentContentViewController = NSViewController()
    private let contentRootView = FolderDropView()
    private let markdownWebView = MarkdownWebView()
    private let emptyStateView = EmptyStateView()
    private let searchBarView = SearchBarView()
    private let dragOverlayView = DragOverlayView()

    private var sidebarItem: NSSplitViewItem!
    private var contentItem: NSSplitViewItem!
    private var searchBarHeightConstraint: NSLayoutConstraint!
    private var session: FolderSession?
    private var fileWatcher = FileWatcher()
    private var settings: AppSettings

    var isEmpty: Bool {
        session == nil
    }

    var selectedFileURL: URL? {
        session?.selectedFileURL
    }

    init(settingsStore: SettingsStore, bookmarkStore: SecurityScopedBookmarkStore, windowManager: WindowManager) {
        self.settingsStore = settingsStore
        self.bookmarkStore = bookmarkStore
        self.windowManager = windowManager
        self.settings = settingsStore.settings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SkimDown"
        window.minSize = NSSize(width: 960, height: 660)
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace, .managed]

        super.init(window: window)

        window.delegate = self
        sidebarViewController.delegate = self
        emptyStateView.delegate = self
        markdownWebView.delegate = self
        searchBarView.delegate = self
        searchBarView.isCaseSensitive = settings.isSearchCaseSensitive

        configureContentView()
        configureSplitView()
        contentRootView.onFolderDropped = { [weak self] folderURL in
            self?.handleDroppedFolder(folderURL)
        }
        sidebarViewController.onFolderDropped = { [weak self] folderURL in
            self?.handleDroppedFolder(folderURL)
        }
        dragOverlayView.onFolderDropped = { [weak self] folderURL in
            self?.handleDroppedFolder(folderURL)
        }

        applyWindowAppearance(settings.theme)
        showEmptyState(.initial)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        fileWatcher.stop()
        session?.securityAccess?.stop()
        windowManager?.controllerDidClose(self)
    }

    func placeWindowOnActiveScreenIfNeeded() {
        guard let window else {
            return
        }

        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else {
            window.center()
            return
        }

        let preferredSize = NSSize(
            width: min(max(window.frame.width, 960), visibleFrame.width - 40),
            height: min(max(window.frame.height, 660), visibleFrame.height - 40)
        )
        let origin = NSPoint(
            x: visibleFrame.midX - preferredSize.width / 2,
            y: visibleFrame.midY - preferredSize.height / 2
        )
        let targetFrame = NSRect(origin: origin, size: preferredSize)

        if !visibleFrame.intersects(window.frame) || !window.isVisible {
            window.setFrame(targetFrame, display: true)
        }
    }

    func openFolder(_ folderURL: URL, securityAccess: SecurityScopedAccess? = nil, bookmarkData: Data? = nil) {
        do {
            let bookmark = try bookmarkData ?? bookmarkStore.bookmarkData(for: folderURL)
            settingsStore.recordRecentFolderBookmark(bookmark)
            let access = securityAccess ?? SecurityScopedAccess(url: folderURL)
            try loadFolder(folderURL: folderURL, securityAccess: access, preferredSelection: nil)
        } catch {
            showOpenError(error)
        }
    }

    func requestFolderSelectionForThisWindow() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Folder"

        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }
            self?.openFolder(url)
        }

        if let window {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    func revealInFinder() {
        guard let selectedFileURL else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([selectedFileURL])
    }

    func copyFilePath() {
        guard let selectedFileURL else {
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedFileURL.path, forType: .string)
    }

    func copySelection() {
        markdownWebView.copySelection()
    }

    func selectAllContent() {
        markdownWebView.selectAll()
    }

    func showFind() {
        guard selectedFileURL != nil else {
            return
        }
        setSearchBarVisible(true)
        searchBarView.focus()
        performSearch()
    }

    func findNext() {
        if searchBarView.isHidden {
            showFind()
            return
        }
        markdownWebView.findNext { [weak self] result in
            self?.searchBarView.setResult(result)
        }
    }

    func findPrevious() {
        if searchBarView.isHidden {
            showFind()
            return
        }
        markdownWebView.findPrevious { [weak self] result in
            self?.searchBarView.setResult(result)
        }
    }

    func useSelectionForFind() {
        showFind()
        markdownWebView.selectedText { [weak self] selectedText in
            let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return
            }
            self?.searchBarView.setQuery(trimmed)
        }
    }

    func toggleSidebar() {
        settings.isSidebarVisible.toggle()
        settingsStore.isSidebarVisible = settings.isSidebarVisible
        sidebarItem.isCollapsed = !settings.isSidebarVisible
    }

    func moveSidebar(to position: SidebarPosition) {
        guard settings.sidebarPosition != position else {
            return
        }
        settings.sidebarPosition = position
        settingsStore.sidebarPosition = position
        rebuildSplitItems()
    }

    func changeFontSize(by delta: Double) {
        setFontSize(settings.fontSize + delta)
    }

    func setFontSize(_ size: Double) {
        settings.fontSize = max(11, min(size, 28))
        settingsStore.fontSize = settings.fontSize
        reloadSelectedMarkdown()
    }

    func setTheme(_ theme: AppTheme) {
        settings.theme = theme
        settingsStore.theme = theme
        applyWindowAppearance(theme)
        reloadSelectedMarkdown()
    }

    override func cancelOperation(_ sender: Any?) {
        setSearchBarVisible(false)
    }

    func sidebarViewController(_ controller: SidebarViewController, didSelectFile fileURL: URL) {
        selectFile(fileURL, anchor: nil)
    }

    func sidebarViewController(_ controller: SidebarViewController, didChangeExpandedPaths paths: Set<String>) {
        guard let session else {
            return
        }
        settingsStore.setExpandedTreeItemRelativePaths(paths, for: session.folderURL)
    }

    func emptyStateViewDidRequestOpenFolder(_ view: EmptyStateView) {
        requestFolderSelectionForThisWindow()
    }

    func markdownWebView(_ webView: MarkdownWebView, didRequestLink href: String) {
        guard let session, let currentFileURL = session.selectedFileURL else {
            return
        }

        let route = LinkRouter().route(
            href: href,
            currentFileURL: currentFileURL,
            folderURL: session.folderURL,
            markdownFiles: Set(session.markdownFiles.map(\.skimdownCanonicalFileURL))
        )

        switch route {
        case .anchor(let anchor):
            markdownWebView.scrollToAnchor(anchor)
        case .markdownFile(let fileURL, let anchor):
            selectFile(fileURL, anchor: anchor)
        case .external(let url):
            NSWorkspace.shared.open(url)
        case .localResource, .blocked:
            NSSound.beep()
        }
    }

    func searchBarView(_ searchBarView: SearchBarView, didChangeQuery query: String, caseSensitive: Bool) {
        settings.isSearchCaseSensitive = caseSensitive
        settingsStore.isSearchCaseSensitive = caseSensitive
        performSearch()
    }

    func searchBarViewDidRequestNext(_ searchBarView: SearchBarView) {
        findNext()
    }

    func searchBarViewDidRequestPrevious(_ searchBarView: SearchBarView) {
        findPrevious()
    }

    func searchBarViewDidRequestClose(_ searchBarView: SearchBarView) {
        setSearchBarVisible(false)
    }

    private func configureContentView() {
        contentRootView.translatesAutoresizingMaskIntoConstraints = false
        markdownWebView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        searchBarView.translatesAutoresizingMaskIntoConstraints = false
        dragOverlayView.translatesAutoresizingMaskIntoConstraints = false
        searchBarView.isHidden = true
        searchBarHeightConstraint = searchBarView.heightAnchor.constraint(equalToConstant: 0)

        contentRootView.addSubview(markdownWebView)
        contentRootView.addSubview(emptyStateView)
        contentRootView.addSubview(searchBarView)
        contentRootView.addSubview(dragOverlayView, positioned: .above, relativeTo: nil)
        documentContentViewController.view = contentRootView

        NSLayoutConstraint.activate([
            searchBarView.leadingAnchor.constraint(equalTo: contentRootView.leadingAnchor),
            searchBarView.trailingAnchor.constraint(equalTo: contentRootView.trailingAnchor),
            searchBarView.topAnchor.constraint(equalTo: contentRootView.topAnchor),
            searchBarHeightConstraint,

            markdownWebView.leadingAnchor.constraint(equalTo: contentRootView.leadingAnchor),
            markdownWebView.trailingAnchor.constraint(equalTo: contentRootView.trailingAnchor),
            markdownWebView.topAnchor.constraint(equalTo: searchBarView.bottomAnchor),
            markdownWebView.bottomAnchor.constraint(equalTo: contentRootView.bottomAnchor),

            emptyStateView.leadingAnchor.constraint(equalTo: contentRootView.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: contentRootView.trailingAnchor),
            emptyStateView.topAnchor.constraint(equalTo: contentRootView.topAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: contentRootView.bottomAnchor),

            dragOverlayView.leadingAnchor.constraint(equalTo: contentRootView.leadingAnchor),
            dragOverlayView.trailingAnchor.constraint(equalTo: contentRootView.trailingAnchor),
            dragOverlayView.topAnchor.constraint(equalTo: contentRootView.topAnchor),
            dragOverlayView.bottomAnchor.constraint(equalTo: contentRootView.bottomAnchor)
        ])
    }

    private func configureSplitView() {
        sidebarItem = NSSplitViewItem(viewController: sidebarViewController)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 520
        sidebarItem.canCollapse = true
        sidebarItem.isCollapsed = !settings.isSidebarVisible

        contentItem = NSSplitViewItem(viewController: documentContentViewController)
        splitViewController.splitView.dividerStyle = .thin
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(splitViewDidResizeSubviewsNotification(_:)),
            name: NSSplitView.didResizeSubviewsNotification,
            object: splitViewController.splitView
        )
        rebuildSplitItems()
        window?.contentViewController = splitViewController
    }

    @objc private func splitViewDidResizeSubviewsNotification(_ notification: Notification) {
        guard !sidebarItem.isCollapsed, splitViewController.splitView.subviews.count == 2 else {
            return
        }

        let splitView = splitViewController.splitView
        let sidebarIndex = settings.sidebarPosition == .left ? 0 : 1
        let width = splitView.subviews[sidebarIndex].bounds.width
        guard width > 0 else {
            return
        }

        settings.sidebarWidth = width
        settingsStore.sidebarWidth = width
    }

    private func rebuildSplitItems() {
        for item in splitViewController.splitViewItems {
            splitViewController.removeSplitViewItem(item)
        }

        if settings.sidebarPosition == .left {
            splitViewController.addSplitViewItem(sidebarItem)
            splitViewController.addSplitViewItem(contentItem)
        } else {
            splitViewController.addSplitViewItem(contentItem)
            splitViewController.addSplitViewItem(sidebarItem)
        }

        sidebarItem.isCollapsed = !settings.isSidebarVisible
        DispatchQueue.main.async { [weak self] in
            self?.applySidebarWidth()
        }
    }

    private func applySidebarWidth() {
        guard !sidebarItem.isCollapsed else {
            return
        }

        let splitView = splitViewController.splitView
        guard splitView.subviews.count == 2 else {
            return
        }

        if settings.sidebarPosition == .left {
            splitView.setPosition(settings.sidebarWidth, ofDividerAt: 0)
        } else {
            splitView.setPosition(splitView.bounds.width - settings.sidebarWidth, ofDividerAt: 0)
        }
    }

    private func loadFolder(folderURL: URL, securityAccess: SecurityScopedAccess, preferredSelection: URL?) throws {
        let scanner = MarkdownScanner()
        let markdownFiles = try scanner.scan(folderURL: folderURL)
        let treeItems = MarkdownTreeBuilder().buildTree(folderURL: folderURL, markdownFiles: markdownFiles)
        let lastRelativePath = preferredSelection.flatMap { PathSecurity.relativePath(for: $0, in: folderURL) } ?? settingsStore.lastSelectedMarkdownRelativePath(for: folderURL)
        let selectedFile = InitialSelectionResolver().resolve(folderURL: folderURL, markdownFiles: markdownFiles, treeItems: treeItems, lastRelativePath: lastRelativePath)

        session?.securityAccess?.stop()
        session = FolderSession(folderURL: folderURL, treeItems: treeItems, markdownFiles: markdownFiles, selectedFileURL: selectedFile, securityAccess: securityAccess)
        window?.title = "\(folderURL.lastPathComponent) \u{2014} SkimDown"

        sidebarViewController.update(
            folderName: folderURL.skimdownDisplayName,
            markdownCount: markdownFiles.count,
            treeItems: treeItems,
            expandedPaths: settingsStore.expandedTreeItemRelativePaths(for: folderURL)
        )

        if let selectedFile {
            selectFile(selectedFile, anchor: nil)
        } else {
            showEmptyState(markdownFiles.isEmpty ? .noMarkdown : .initial)
        }

        startWatching(folderURL: folderURL)
    }

    private func startWatching(folderURL: URL) {
        do {
            try fileWatcher.start(folderURL: folderURL)
            fileWatcher.onChange = { [weak self] in
                self?.reloadFolderAfterChange()
            }
        } catch {
            showOpenError(error)
        }
    }

    private func reloadFolderAfterChange() {
        guard let session else {
            return
        }

        let previousSelection = session.selectedFileURL
        let folderURL = session.folderURL
        do {
            let scanner = MarkdownScanner()
            let markdownFiles = try scanner.scan(folderURL: folderURL)
            let treeItems = MarkdownTreeBuilder().buildTree(folderURL: folderURL, markdownFiles: markdownFiles)
            let stillSelected = previousSelection.flatMap { previous in
                markdownFiles.contains(where: { $0.skimdownCanonicalFileURL == previous.skimdownCanonicalFileURL }) ? previous : nil
            }

            session.treeItems = treeItems
            session.markdownFiles = markdownFiles
            session.selectedFileURL = stillSelected

            sidebarViewController.update(
                folderName: folderURL.skimdownDisplayName,
                markdownCount: markdownFiles.count,
                treeItems: treeItems,
                expandedPaths: settingsStore.expandedTreeItemRelativePaths(for: folderURL)
            )

            if let stillSelected {
                selectFile(stillSelected, anchor: nil)
            } else {
                settingsStore.setLastSelectedMarkdown(nil, for: folderURL)
                showEmptyState(markdownFiles.isEmpty ? .noMarkdown : .initial)
            }
        } catch {
            showOpenError(error)
        }
    }

    private func selectFile(_ fileURL: URL, anchor: String?) {
        guard let session, PathSecurity.isFileURL(fileURL, containedIn: session.folderURL) else {
            NSSound.beep()
            return
        }

        do {
            let markdown = try MarkdownDocumentLoader().load(fileURL: fileURL)
            session.selectedFileURL = fileURL.skimdownCanonicalFileURL
            settingsStore.setLastSelectedMarkdown(fileURL, for: session.folderURL)
            sidebarViewController.selectFile(fileURL)
            emptyStateView.isHidden = true
            markdownWebView.isHidden = false
            markdownWebView.render(markdown: markdown, currentFileURL: fileURL, rootFolderURL: session.folderURL, theme: settings.theme, fontSize: settings.fontSize) { [weak self] in
                if let anchor {
                    self?.markdownWebView.scrollToAnchor(anchor)
                }
            }
            performSearch()
        } catch {
            session.selectedFileURL = fileURL.skimdownCanonicalFileURL
            sidebarViewController.selectFile(fileURL)
            emptyStateView.isHidden = true
            markdownWebView.isHidden = false
            markdownWebView.showError(error.localizedDescription, theme: settings.theme, fontSize: settings.fontSize)
        }
    }

    private func reloadSelectedMarkdown() {
        guard let selectedFileURL else {
            return
        }
        selectFile(selectedFileURL, anchor: nil)
    }

    private func showEmptyState(_ state: EmptyStateView.State) {
        emptyStateView.configure(state)
        emptyStateView.isHidden = false
        markdownWebView.isHidden = true
        setSearchBarVisible(false)
        if session == nil {
            window?.title = "SkimDown"
        }
    }

    private func performSearch() {
        guard !searchBarView.isHidden else {
            return
        }
        markdownWebView.performSearch(query: searchBarView.query, caseSensitive: searchBarView.isCaseSensitive) { [weak self] result in
            self?.searchBarView.setResult(result)
        }
    }

    private func setSearchBarVisible(_ isVisible: Bool) {
        searchBarView.isHidden = !isVisible
        searchBarHeightConstraint.constant = isVisible ? 44 : 0
    }

    private func handleDroppedFolder(_ folderURL: URL) {
        if isEmpty || session?.markdownFiles.isEmpty == true {
            openFolder(folderURL)
        } else {
            windowManager?.openFolder(folderURL, preferExistingEmptyWindow: false)
        }
    }

    private func applyWindowAppearance(_ theme: AppTheme) {
        switch theme {
        case .system:
            window?.appearance = nil
        case .light:
            window?.appearance = NSAppearance(named: .aqua)
        case .dark:
            window?.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func showOpenError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not open folder"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
