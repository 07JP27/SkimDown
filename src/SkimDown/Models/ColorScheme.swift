import Foundation

/// VS Code-compatible color theme JSON / JSONC representation.
///
/// SkimDown uses only `name`, `type`, and `colors`. Other keys such as
/// `tokenColors` are ignored for now.
///
/// Reference: https://code.visualstudio.com/api/references/theme-color
struct ColorScheme: Equatable {
    enum ThemeType: String, Equatable {
        case light
        case dark
        case highContrastLight = "hc-light"
        case highContrastDark = "hc-black"

        /// Whether the theme is dark-leaning, used for UI fallback values and Mermaid theme selection.
        var isDark: Bool {
            switch self {
            case .dark, .highContrastDark: return true
            case .light, .highContrastLight: return false
            }
        }
    }

    /// Unique identifier derived from the file name, such as `monokai-dimmed`.
    let id: String
    /// JSON `name`, falling back to `id` when omitted.
    let displayName: String
    let type: ThemeType
    /// VS Code `colors` dictionary, such as `editor.background` -> `#1e1e1e`.
    let colors: [String: String]
}

extension ColorScheme {
    /// Decodes a JSON / JSONC file into a `ColorScheme`.
    /// Returns nil when parsing fails or required data is missing.
    static func load(from fileURL: URL) -> ColorScheme? {
        guard let data = try? Data(contentsOf: fileURL),
              let parsed = parseThemeObject(from: data) else {
            return nil
        }
        let id = fileURL.deletingPathExtension().lastPathComponent
        guard !id.isEmpty else { return nil }
        let displayName = (parsed["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? id
        let rawType = (parsed["type"] as? String) ?? "dark"
        let type = ThemeType(rawValue: rawType.lowercased()) ?? .dark
        // VS Code colors are expected to be { String: String }; drop non-string entries.
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

    private static func parseThemeObject(from data: Data) -> [String: Any]? {
        if let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any] {
            return parsed
        }
        guard var text = String(data: data, encoding: .utf8) else {
            return nil
        }
        if text.first == "\u{feff}" {
            text.removeFirst()
        }
        let normalized = removeTrailingCommas(from: removeJSONCComments(from: text))
        guard let normalizedData = normalized.data(using: .utf8) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: normalizedData, options: [.fragmentsAllowed]) as? [String: Any]
    }

    private static func removeJSONCComments(from text: String) -> String {
        var result = ""
        var index = text.startIndex
        var isInString = false
        var isEscaping = false

        while index < text.endIndex {
            let character = text[index]

            if isInString {
                result.append(character)
                if isEscaping {
                    isEscaping = false
                } else if character == "\\" {
                    isEscaping = true
                } else if character == "\"" {
                    isInString = false
                }
                index = text.index(after: index)
                continue
            }

            if character == "\"" {
                isInString = true
                result.append(character)
                index = text.index(after: index)
                continue
            }

            if character == "/" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex {
                    let nextCharacter = text[nextIndex]
                    if nextCharacter == "/" {
                        index = text.index(after: nextIndex)
                        while index < text.endIndex, !text[index].isNewline {
                            index = text.index(after: index)
                        }
                        continue
                    }
                    if nextCharacter == "*" {
                        result.append(" ")
                        index = text.index(after: nextIndex)
                        while index < text.endIndex {
                            if text[index].isNewline {
                                result.append(text[index])
                            }
                            let commentIndex = index
                            index = text.index(after: index)
                            if text[commentIndex] == "*", index < text.endIndex, text[index] == "/" {
                                index = text.index(after: index)
                                break
                            }
                        }
                        continue
                    }
                }
            }

            result.append(character)
            index = text.index(after: index)
        }

        return result
    }

    private static func removeTrailingCommas(from text: String) -> String {
        var result = ""
        var index = text.startIndex
        var isInString = false
        var isEscaping = false

        while index < text.endIndex {
            let character = text[index]

            if isInString {
                result.append(character)
                if isEscaping {
                    isEscaping = false
                } else if character == "\\" {
                    isEscaping = true
                } else if character == "\"" {
                    isInString = false
                }
                index = text.index(after: index)
                continue
            }

            if character == "\"" {
                isInString = true
                result.append(character)
                index = text.index(after: index)
                continue
            }

            if character == "," {
                var lookahead = text.index(after: index)
                while lookahead < text.endIndex, text[lookahead].isWhitespace {
                    lookahead = text.index(after: lookahead)
                }
                if lookahead < text.endIndex, (text[lookahead] == "}" || text[lookahead] == "]") {
                    index = text.index(after: index)
                    continue
                }
            }

            result.append(character)
            index = text.index(after: index)
        }

        return result
    }
}
