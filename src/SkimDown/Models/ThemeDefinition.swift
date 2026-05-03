import Foundation

struct ThemeColors: Equatable, Codable {
    var bg: String
    var fg: String
    var muted: String
    var border: String
    var subtle: String
    var surface: String
    var accent: String
    var mark: String
    var currentMark: String

    var cssVariables: [String: String] {
        [
            "--skimdown-bg": bg,
            "--skimdown-fg": fg,
            "--skimdown-muted": muted,
            "--skimdown-border": border,
            "--skimdown-subtle": subtle,
            "--skimdown-surface": surface,
            "--skimdown-accent": accent,
            "--skimdown-mark": mark,
            "--skimdown-current-mark": currentMark
        ]
    }
}

enum ThemeColorScheme: String, Codable, CaseIterable {
    case light
    case dark
}

struct ThemeDefinition: Identifiable, Equatable {
    let id: String
    let name: String
    let colorScheme: ThemeColorScheme
    let colors: ThemeColors
    let isBuiltIn: Bool
    /// Window background opacity (0.5–1.0). 1.0 = fully opaque (default).
    let opacity: Double

    static let builtInLight = ThemeDefinition(
        id: "builtin-light",
        name: "Default Light",
        colorScheme: .light,
        colors: ThemeColors(
            bg: "#fbfbfd",
            fg: "#20242c",
            muted: "#69707d",
            border: "rgba(31, 35, 40, 0.14)",
            subtle: "#f4f6f8",
            surface: "rgba(255, 255, 255, 0.72)",
            accent: "#0a66d6",
            mark: "#fff8c5",
            currentMark: "#ffd33d"
        ),
        isBuiltIn: true,
        opacity: 1.0
    )

    static let builtInDark = ThemeDefinition(
        id: "builtin-dark",
        name: "Default Dark",
        colorScheme: .dark,
        colors: ThemeColors(
            bg: "#0f1116",
            fg: "#e8ebf1",
            muted: "#a0a7b4",
            border: "rgba(215, 224, 238, 0.15)",
            subtle: "#171b22",
            surface: "rgba(255, 255, 255, 0.04)",
            accent: "#69a7ff",
            mark: "#6e4f00",
            currentMark: "#9e6a03"
        ),
        isBuiltIn: true,
        opacity: 1.0
    )
}

/// On-disk JSON representation for user-created themes.
struct ThemeFile: Codable {
    let name: String
    let colorScheme: ThemeColorScheme
    let colors: ThemeColors
    /// Window background opacity (0.5–1.0). Defaults to 1.0 if omitted.
    let opacity: Double?
}
