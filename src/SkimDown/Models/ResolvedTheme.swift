import Foundation

/// VS Code カラーテーマ JSON を SkimDown の CSS 変数へ解決した中間表現。
///
/// `MarkdownWebView` はこの構造体を受け取り、`<style>:root[data-theme="custom"]{...}`
/// を生成して HTML に注入する。値が無い項目は `type` (light/dark) に応じた
/// フォールバックを適用済み。
struct ResolvedTheme: Equatable {
    let id: String
    let displayName: String
    let type: ColorScheme.ThemeType
    /// CSS 変数名 (先頭の `--` を含む) → CSS 互換の色文字列。
    let cssVariables: [(name: String, value: String)]

    static func == (lhs: ResolvedTheme, rhs: ResolvedTheme) -> Bool {
        guard lhs.id == rhs.id,
              lhs.displayName == rhs.displayName,
              lhs.type == rhs.type,
              lhs.cssVariables.count == rhs.cssVariables.count else {
            return false
        }
        return zip(lhs.cssVariables, rhs.cssVariables)
            .allSatisfy { $0.name == $1.name && $0.value == $1.value }
    }

    var isDark: Bool { type.isDark }
}

extension ResolvedTheme {
    /// `ColorScheme` から `ResolvedTheme` を作る。
    ///
    /// VS Code の色キーが欠けている場合は `type` に応じたフォールバック値を入れる。
    static func resolve(from scheme: ColorScheme) -> ResolvedTheme {
        let fallback = FallbackPalette.for(type: scheme.type)
        let mapping = ColorMapping.allMappings

        var resolved: [(name: String, value: String)] = []
        resolved.reserveCapacity(mapping.count)
        for entry in mapping {
            let value = entry.vsCodeKeys
                .lazy
                .compactMap { scheme.colors[$0] }
                .compactMap(normalizeColor(_:))
                .first ?? fallback[entry.cssVariable] ?? "inherit"
            resolved.append((name: entry.cssVariable, value: value))
        }
        return ResolvedTheme(
            id: scheme.id,
            displayName: scheme.displayName,
            type: scheme.type,
            cssVariables: resolved
        )
    }

    /// VS Code は `#rrggbbaa` のように先頭シャープ + 8桁アルファを使う。
    /// CSS でも有効な形に整える (基本そのまま通すが、空文字や明らかな
    /// 不正値は弾く)。
    private static func normalizeColor(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

/// VS Code のキー → SkimDown CSS 変数のマッピングテーブル。
private enum ColorMapping {
    struct Entry {
        let cssVariable: String
        /// 優先順に並んだ VS Code のキー。最初に見つかったものを使う。
        let vsCodeKeys: [String]
    }

    static let allMappings: [Entry] = [
        Entry(cssVariable: "--skimdown-bg", vsCodeKeys: [
            "editor.background"
        ]),
        Entry(cssVariable: "--skimdown-fg", vsCodeKeys: [
            "editor.foreground",
            "foreground"
        ]),
        Entry(cssVariable: "--skimdown-muted", vsCodeKeys: [
            "descriptionForeground",
            "disabledForeground"
        ]),
        Entry(cssVariable: "--skimdown-border", vsCodeKeys: [
            "panel.border",
            "editorGroup.border",
            "editorWidget.border",
            "contrastBorder"
        ]),
        Entry(cssVariable: "--skimdown-subtle", vsCodeKeys: [
            "editorGroupHeader.tabsBackground",
            "editor.lineHighlightBackground",
            "sideBar.background"
        ]),
        Entry(cssVariable: "--skimdown-surface", vsCodeKeys: [
            "editorWidget.background",
            "editor.background"
        ]),
        Entry(cssVariable: "--skimdown-accent", vsCodeKeys: [
            "textLink.foreground",
            "editorLink.activeForeground",
            "focusBorder"
        ]),
        Entry(cssVariable: "--skimdown-mark", vsCodeKeys: [
            "editor.findMatchHighlightBackground"
        ]),
        Entry(cssVariable: "--skimdown-current-mark", vsCodeKeys: [
            "editor.findMatchBackground"
        ])
    ]
}

/// VS Code キーが無いときに使うフォールバック値。
/// 既存の `skimdown.css` のライト / ダーク既定とそろえる。
private enum FallbackPalette {
    static func `for`(type: ColorScheme.ThemeType) -> [String: String] {
        type.isDark ? darkFallback : lightFallback
    }

    private static let lightFallback: [String: String] = [
        "--skimdown-bg": "#fbfbfd",
        "--skimdown-fg": "#20242c",
        "--skimdown-muted": "#69707d",
        "--skimdown-border": "rgba(31, 35, 40, 0.14)",
        "--skimdown-subtle": "#f4f6f8",
        "--skimdown-surface": "rgba(255, 255, 255, 0.72)",
        "--skimdown-accent": "#0a66d6",
        "--skimdown-mark": "#fff8c5",
        "--skimdown-current-mark": "#ffd33d"
    ]

    private static let darkFallback: [String: String] = [
        "--skimdown-bg": "#0f1116",
        "--skimdown-fg": "#e8ebf1",
        "--skimdown-muted": "#a0a7b4",
        "--skimdown-border": "rgba(215, 224, 238, 0.15)",
        "--skimdown-subtle": "#171b22",
        "--skimdown-surface": "rgba(255, 255, 255, 0.04)",
        "--skimdown-accent": "#69a7ff",
        "--skimdown-mark": "#6e4f00",
        "--skimdown-current-mark": "#9e6a03"
    ]
}
