import Foundation

final class SettingsStore {
    private enum Key {
        static let lastFolderBookmark = "lastFolderBookmark"
        static let recentFolderBookmarks = "recentFolderBookmarks"
        static let lastSelectedMarkdownByFolder = "lastSelectedMarkdownByFolder"
        static let expandedTreeItemsByFolder = "expandedTreeItemsByFolder"
        static let sidebarPosition = "sidebarPosition"
        static let isSidebarVisible = "isSidebarVisible"
        static let sidebarWidth = "sidebarWidth"
        static let theme = "theme"
        static let fontSize = "fontSize"
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
                fontSize: fontSize,
                isSearchCaseSensitive: isSearchCaseSensitive
            )
        }
        set {
            sidebarPosition = newValue.sidebarPosition
            isSidebarVisible = newValue.isSidebarVisible
            sidebarWidth = newValue.sidebarWidth
            theme = newValue.theme
            fontSize = newValue.fontSize
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
            return value > 0 ? value : 260
        }
        set { defaults.set(max(180, min(newValue, 520)), forKey: Key.sidebarWidth) }
    }

    var theme: AppTheme {
        get { AppTheme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Key.theme) }
    }

    var fontSize: Double {
        get {
            let value = defaults.double(forKey: Key.fontSize)
            return value > 0 ? value : 16
        }
        set { defaults.set(max(11, min(newValue, 28)), forKey: Key.fontSize) }
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

