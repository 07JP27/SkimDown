import Foundation
import os.log

/// Discovers, parses, and caches user-registered color theme JSON files from
/// `~/Library/Application Support/SkimDown/Themes/`.
///
/// The directory is not watched automatically. `reload()` is called from the
/// Reload Themes menu item.
@MainActor
final class ColorSchemeStore {
    private static let log = Logger(subsystem: "dev.jp27.SkimDown", category: "ColorSchemeStore")

    private let themesDirectoryURL: URL
    private let fileManager: FileManager
    private(set) var schemes: [ColorScheme] = []
    private var resolvedCache: [String: ResolvedTheme] = [:]

    /// Allows tests to provide a custom themes directory.
    init(themesDirectoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.themesDirectoryURL = themesDirectoryURL ?? Self.defaultThemesDirectoryURL(fileManager: fileManager)
    }

    var directoryURL: URL { themesDirectoryURL }

    /// Default storage location: `~/Library/Application Support/SkimDown/Themes`.
    /// Falls back to the temporary directory if Application Support is unavailable.
    static func defaultThemesDirectoryURL(fileManager: FileManager = .default) -> URL {
        let base: URL
        if let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            base = appSupport
        } else {
            base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }
        return base.appendingPathComponent("SkimDown", isDirectory: true)
            .appendingPathComponent("Themes", isDirectory: true)
    }

            /// Ensures the storage directory exists and reloads the latest JSON list.
    @discardableResult
    func reload() -> [ColorScheme] {
        ensureDirectoryExists()
        resolvedCache.removeAll(keepingCapacity: true)
        let urls = jsonFileURLs()
        var loaded: [ColorScheme] = []
        var seenIds = Set<String>()
        for url in urls {
            guard let scheme = ColorScheme.load(from: url) else {
                Self.log.warning("Skipping invalid theme JSON: \(url.lastPathComponent, privacy: .public)")
                continue
            }
            // Theme IDs come from file names and should be unique, but ignore duplicates defensively.
            guard seenIds.insert(scheme.id).inserted else { continue }
            loaded.append(scheme)
        }
        loaded.sort { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        schemes = loaded
        return loaded
    }

    func scheme(id: String) -> ColorScheme? {
        schemes.first(where: { $0.id == id })
    }

    /// Returns the resolved display theme for a custom `AppTheme`.
    /// Built-in themes (system/light/dark) return nil.
    func resolvedTheme(for theme: AppTheme) -> ResolvedTheme? {
        guard case .custom(let id) = theme else { return nil }
        if let cached = resolvedCache[id] { return cached }
        guard let scheme = scheme(id: id) else { return nil }
        let resolved = ResolvedTheme.resolve(from: scheme)
        resolvedCache[id] = resolved
        return resolved
    }

    /// Normalizes a persisted theme against the currently registered themes.
    /// Missing custom themes fall back to System.
    func normalizedTheme(_ theme: AppTheme) -> AppTheme {
        guard case .custom(let id) = theme else { return theme }
        return scheme(id: id) == nil ? .system : theme
    }

    /// Creates the storage directory when it is missing. Failures are only logged.
    func ensureDirectoryExists() {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: themesDirectoryURL.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                Self.log.error("Themes path exists but is not a directory: \(self.themesDirectoryURL.path, privacy: .private)")
            }
            return
        }

        do {
            try fileManager.createDirectory(at: themesDirectoryURL, withIntermediateDirectories: true)
        } catch {
            Self.log.error("Failed to create themes directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func jsonFileURLs() -> [URL] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: themesDirectoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return []
        }
        return entries
            .filter { url in
                guard url.pathExtension.lowercased() == "json",
                      let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
                    return false
                }
                return values.isRegularFile == true && values.isSymbolicLink != true
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
