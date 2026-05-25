import Foundation

/// Intermediate representation that resolves VS Code color theme JSON into SkimDown CSS variables.
///
/// `MarkdownWebView` injects this as `<style>:root[data-theme="custom"][data-theme-type]{...}`.
/// Missing values are already filled from the light/dark fallback palette based on `type`.
struct ResolvedTheme: Equatable {
    let id: String
    let displayName: String
    let type: ColorScheme.ThemeType
    /// CSS variable name, including the leading `--`, mapped to a CSS-compatible color value.
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
    /// Creates a resolved theme from a `ColorScheme`.
    /// Missing VS Code color keys are filled from the palette for the theme `type`.
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

    /// Allows only color values that are safe to embed in CSS.
    /// VS Code themes usually use `#rrggbb` / `#rrggbbaa`, but `rgb[a]()`, `hsl[a]()`,
    /// and `transparent` are accepted for compatibility with existing theme assets.
    private static func normalizeColor(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowercased = trimmed.lowercased()
        if lowercased == "transparent" {
            return lowercased
        }
        if isHexColor(lowercased) {
            return trimmed
        }
        if isColorFunction(lowercased, name: "rgb", allowedCharacters: rgbFunctionCharacters)
            || isColorFunction(lowercased, name: "rgba", allowedCharacters: rgbFunctionCharacters)
            || isColorFunction(lowercased, name: "hsl", allowedCharacters: hslFunctionCharacters)
            || isColorFunction(lowercased, name: "hsla", allowedCharacters: hslFunctionCharacters) {
            return trimmed
        }
        return nil
    }

    private static func isHexColor(_ value: String) -> Bool {
        guard value.first == "#" else { return false }
        let hex = value.dropFirst()
        guard [3, 4, 6, 8].contains(hex.count) else { return false }
        return hex.allSatisfy { character in
            character.isHexDigit
        }
    }

    private static func isColorFunction(_ value: String, name: String, allowedCharacters: CharacterSet) -> Bool {
        let prefix = "\(name)("
        guard value.hasPrefix(prefix), value.hasSuffix(")") else {
            return false
        }
        let inner = value.dropFirst(prefix.count).dropLast()
        guard !inner.isEmpty else { return false }
        return inner.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }

    private static let rgbFunctionCharacters = CharacterSet(charactersIn: "0123456789.,% /+-")
    private static let hslFunctionCharacters = CharacterSet(charactersIn: "0123456789.,% /+-abcdefghijklmnopqrstuvwxyz")
}

/// Mapping table from VS Code keys to SkimDown CSS variables.
private enum ColorMapping {
    struct Entry {
        let cssVariable: String
        /// VS Code keys in priority order. The first matching key wins.
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

/// Fallback values used when a VS Code key is missing.
/// These match the built-in light/dark defaults from `skimdown.css`.
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
