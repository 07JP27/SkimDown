import Foundation

/// VS Code 互換のカラーテーマ JSON 表現。
///
/// SkimDown は `name`, `type`, `colors` のみを使用する。`tokenColors`
/// などその他のキーは無視する (将来拡張)。
///
/// 参考: https://code.visualstudio.com/api/references/theme-color
struct ColorScheme: Equatable {
    enum ThemeType: String, Equatable {
        case light
        case dark
        case highContrastLight = "hc-light"
        case highContrastDark = "hc-black"

        /// 暗色寄りかどうか (UI フォールバック値や Mermaid テーマ選択に使う)。
        var isDark: Bool {
            switch self {
            case .dark, .highContrastDark: return true
            case .light, .highContrastLight: return false
            }
        }
    }

    /// ファイル名由来の一意な識別子 (例: `monokai-dimmed`)。
    let id: String
    /// JSON 内の `name`。なければ id を流用。
    let displayName: String
    let type: ThemeType
    /// VS Code の `colors` 辞書 (例: `editor.background` → `#1e1e1e`)。
    let colors: [String: String]
}

extension ColorScheme {
    /// 指定 URL の JSON を `ColorScheme` にデコードする。
    /// パース不能・必須フィールド欠落は `nil`。
    static func load(from fileURL: URL) -> ColorScheme? {
        guard let data = try? Data(contentsOf: fileURL),
              let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] else {
            return nil
        }
        let id = fileURL.deletingPathExtension().lastPathComponent
        guard !id.isEmpty else { return nil }
        let displayName = (parsed["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? id
        let rawType = (parsed["type"] as? String) ?? "dark"
        let type = ThemeType(rawValue: rawType.lowercased()) ?? .dark
        // VS Code 形式の colors は { String: String }。型不一致のエントリは捨てる。
        let rawColors = parsed["colors"] as? [String: Any] ?? [:]
        var colors: [String: String] = [:]
        colors.reserveCapacity(rawColors.count)
        for (key, value) in rawColors {
            if let string = value as? String {
                colors[key] = string
            }
        }
        return ColorScheme(id: id, displayName: displayName, type: type, colors: colors)
    }
}
