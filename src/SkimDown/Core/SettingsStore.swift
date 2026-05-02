import Foundation

final class SettingsStore {
    private enum Key {
        static let lastFolderBookmark = "lastFolderBookmark"
        static let recentFolderBookmarks = "recentFolderBookmarks"
        static let openFolderBookmarks = "openFolderBookmarks"
        static let openFolderStates = "openFolderStates"
        static let lastSelectedMarkdownByFolder = "lastSelectedMarkdownByFolder"
        static let expandedTreeItemsByFolder = "expandedTreeItemsByFolder"
        static let sidebarPosition = "sidebarPosition"
        static let isSidebarVisible = "isSidebarVisible"
        static let sidebarWidth = "sidebarWidth"
        static let theme = "theme"
        static let customThemeID = "customThemeID"
        static let fontSize = "fontSize"
        static let fontFamily = "fontFamily"
        static let isSearchCaseSensitive = "isSearchCaseSensitive"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var settings: AppSettings {
        get {
            AppSettings(
                sidebarPosition: sidebarPosition,
                isSidebarVisible: isSidebarVisible,
                sidebarWidth: sidebarWidth,
                theme: theme,
                customThemeID: customThemeID,
                fontSize: fontSize,
                fontFamily: fontFamily,
                isSearchCaseSensitive: isSearchCaseSensitive
            )
        }
        set {
            sidebarPosition = newValue.sidebarPosition
            isSidebarVisible = newValue.isSidebarVisible
            sidebarWidth = newValue.sidebarWidth
            theme = newValue.theme
            customThemeID = newValue.customThemeID
            fontSize = newValue.fontSize
            fontFamily = newValue.fontFamily
            isSearchCaseSensitive = newValue.isSearchCaseSensitive
        }
    }

    var lastFolderBookmark: Data? {
        get { defaults.data(forKey: Key.lastFolderBookmark) }
        set { defaults.set(newValue, forKey: Key.lastFolderBookmark) }
    }

    var recentFolderBookmarks: [Data] {
        get { defaults.array(forKey: Key.recentFolderBookmarks) as? [Data] ?? [] }
        set { defaults.set(newValue, forKey: Key.recentFolderBookmarks) }
    }

    /// Bookmarks for folders currently open in active windows.
    ///
    /// This is independent of `recentFolderBookmarks` / `lastFolderBookmark`
    /// (which represent history) and reflects the live state of open windows
    /// so that all of them can be restored on next launch.
    var openFolderBookmarks: [Data] {
        get { defaults.array(forKey: Key.openFolderBookmarks) as? [Data] ?? [] }
        set { defaults.set(newValue, forKey: Key.openFolderBookmarks) }
    }

    /// Persisted state for each currently-open folder window: the folder
    /// bookmark plus the on-screen frame, so windows are restored at the
    /// same position and size on next launch.
    ///
    /// Falls back to legacy `openFolderBookmarks` when no states have been
    /// written yet (one-time migration). Writing clears the legacy key.
    var openFolderStates: [OpenFolderState] {
        get {
            if let raw = defaults.array(forKey: Key.openFolderStates) as? [[String: Any]] {
                return raw.compactMap(OpenFolderState.init(dictionary:))
            }
            // Legacy migration: bookmarks-only storage without frames.
            return openFolderBookmarks.map { OpenFolderState(bookmark: $0, frame: .zero) }
        }
        set {
            let raw = newValue.map { $0.dictionaryRepresentation }
            defaults.set(raw, forKey: Key.openFolderStates)
            // Drop the legacy single-key list so we don't double-restore.
            defaults.removeObject(forKey: Key.openFolderBookmarks)
        }
    }

    var sidebarPosition: SidebarPosition {
        get { SidebarPosition(rawValue: defaults.string(forKey: Key.sidebarPosition) ?? "") ?? .left }
        set { defaults.set(newValue.rawValue, forKey: Key.sidebarPosition) }
    }

    var isSidebarVisible: Bool {
        get {
            if defaults.object(forKey: Key.isSidebarVisible) == nil {
                return true
            }
            return defaults.bool(forKey: Key.isSidebarVisible)
        }
        set { defaults.set(newValue, forKey: Key.isSidebarVisible) }
    }

    var sidebarWidth: Double {
        get {
            let value = defaults.double(forKey: Key.sidebarWidth)
            guard value > 0 else { return 260 }
            return max(180, min(value, 520))
        }
        set { defaults.set(max(180, min(newValue, 520)), forKey: Key.sidebarWidth) }
    }

    var theme: AppTheme {
        get { AppTheme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Key.theme) }
    }

    var customThemeID: String? {
        get { defaults.string(forKey: Key.customThemeID) }
        set { defaults.set(newValue, forKey: Key.customThemeID) }
    }

    var fontSize: Double {
        get {
            let value = defaults.double(forKey: Key.fontSize)
            guard value > 0 else { return 16 }
            return max(11, min(value, 28))
        }
        set { defaults.set(max(11, min(newValue, 28)), forKey: Key.fontSize) }
    }

    var fontFamily: String? {
        get { defaults.string(forKey: Key.fontFamily) }
        set { defaults.set(newValue, forKey: Key.fontFamily) }
    }

    var isSearchCaseSensitive: Bool {
        get { defaults.bool(forKey: Key.isSearchCaseSensitive) }
        set { defaults.set(newValue, forKey: Key.isSearchCaseSensitive) }
    }

    func recordRecentFolderBookmark(_ bookmark: Data) {
        var bookmarks = recentFolderBookmarks.filter { $0 != bookmark }
        bookmarks.insert(bookmark, at: 0)
        recentFolderBookmarks = Array(bookmarks.prefix(10))
        lastFolderBookmark = bookmark
    }

    func lastSelectedMarkdownRelativePath(for folderURL: URL) -> String? {
        lastSelectedMarkdownByFolder[PathSecurity.folderKey(for: folderURL)]
    }

    func setLastSelectedMarkdown(_ fileURL: URL?, for folderURL: URL) {
        var values = lastSelectedMarkdownByFolder
        let key = PathSecurity.folderKey(for: folderURL)
        values[key] = fileURL.flatMap { PathSecurity.relativePath(for: $0, in: folderURL) }
        lastSelectedMarkdownByFolder = values
    }

    func expandedTreeItemRelativePaths(for folderURL: URL) -> Set<String> {
        Set(expandedTreeItemsByFolder[PathSecurity.folderKey(for: folderURL)] ?? [])
    }

    func setExpandedTreeItemRelativePaths(_ paths: Set<String>, for folderURL: URL) {
        var values = expandedTreeItemsByFolder
        values[PathSecurity.folderKey(for: folderURL)] = Array(paths).sorted()
        expandedTreeItemsByFolder = values
    }

    private var lastSelectedMarkdownByFolder: [String: String] {
        get { defaults.dictionary(forKey: Key.lastSelectedMarkdownByFolder) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Key.lastSelectedMarkdownByFolder) }
    }

    private var expandedTreeItemsByFolder: [String: [String]] {
        get { defaults.dictionary(forKey: Key.expandedTreeItemsByFolder) as? [String: [String]] ?? [:] }
        set { defaults.set(newValue, forKey: Key.expandedTreeItemsByFolder) }
    }
}

