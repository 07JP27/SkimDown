import Foundation
import os.log

/// `~/Library/Application Support/SkimDown/Themes/` にあるユーザー登録の
/// カラースキーム JSON を発見・パース・キャッシュする。
///
/// 自動監視は行わない (Issue #39 の方針)。`Reload Themes` メニューから
/// `reload()` を呼ぶ。
@MainActor
final class ColorSchemeStore {
    private static let log = Logger(subsystem: "dev.jp27.SkimDown", category: "ColorSchemeStore")

    private let themesDirectoryURL: URL
    private let fileManager: FileManager
    private(set) var schemes: [ColorScheme] = []
    private var resolvedCache: [String: ResolvedTheme] = [:]

    /// テスト用に themes ディレクトリを差し替え可能にする。
    init(themesDirectoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.themesDirectoryURL = themesDirectoryURL ?? Self.defaultThemesDirectoryURL(fileManager: fileManager)
    }

    var directoryURL: URL { themesDirectoryURL }

    /// 既定の保存先 `~/Library/Application Support/SkimDown/Themes`。
    /// Application Support を取得できないときは一時ディレクトリを返す。
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

    /// 保存ディレクトリを作成し直近の JSON 一覧を再読込する。
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
            // id (ファイル名) はユニークになる前提だが、念のため重複は無視する。
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

    /// `AppTheme` から表示用に解決済みのテーマを返す。組み込み (system/light/dark) は `nil`。
    func resolvedTheme(for theme: AppTheme) -> ResolvedTheme? {
        guard case .custom(let id) = theme else { return nil }
        if let cached = resolvedCache[id] { return cached }
        guard let scheme = scheme(id: id) else { return nil }
        let resolved = ResolvedTheme.resolve(from: scheme)
        resolvedCache[id] = resolved
        return resolved
    }

    /// 保存済みテーマが現在の登録状態で有効かを確認する。
    ///
    /// ユーザーが Themes フォルダから JSON を削除した場合など、存在しない
    /// カスタムテーマは `System` に戻す。
    func normalizedTheme(_ theme: AppTheme) -> AppTheme {
        guard case .custom(let id) = theme else { return theme }
        return scheme(id: id) == nil ? .system : theme
    }

    /// 保存先フォルダが無ければ作成する。失敗は黙ってログに残すだけ。
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
