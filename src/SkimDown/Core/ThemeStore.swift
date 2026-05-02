import Foundation

final class ThemeStore {
    private let fileManager = FileManager.default

    private(set) var themes: [ThemeDefinition] = []

    init() {
        reload()
    }

    func reload() {
        var result: [ThemeDefinition] = [.builtInLight, .builtInDark]
        let directory = themesDirectoryURL
        guard fileManager.fileExists(atPath: directory.path) else {
            themes = result
            return
        }

        let files = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        for fileURL in files where fileURL.pathExtension.lowercased() == "json" {
            guard let theme = loadTheme(at: fileURL) else {
                continue
            }
            result.append(theme)
        }

        themes = result
    }

    func theme(for id: String) -> ThemeDefinition? {
        themes.first { $0.id == id }
    }

    func importTheme(from sourceURL: URL) throws -> ThemeDefinition {
        let data = try Data(contentsOf: sourceURL)
        let themeFile = try JSONDecoder().decode(ThemeFile.self, from: data)
        try validateColors(themeFile.colors)

        let directory = themesDirectoryURL
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let sanitized = sanitizeFilename(baseName)
        let destURL = uniqueURL(for: sanitized, in: directory)
        try fileManager.copyItem(at: sourceURL, to: destURL)

        let id = destURL.deletingPathExtension().lastPathComponent
        let theme = ThemeDefinition(
            id: id,
            name: themeFile.name,
            colorScheme: themeFile.colorScheme,
            colors: themeFile.colors,
            isBuiltIn: false,
            opacity: Self.clampOpacity(themeFile.opacity)
        )
        themes.append(theme)
        return theme
    }

    func deleteTheme(id: String) throws {
        guard let theme = theme(for: id), !theme.isBuiltIn else {
            return
        }
        let fileURL = themesDirectoryURL.appendingPathComponent("\(id).json")
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        themes.removeAll { $0.id == id }
    }

    var themesDirectoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SkimDown/themes")
    }

    // MARK: - Private

    private func loadTheme(at fileURL: URL) -> ThemeDefinition? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        guard let themeFile = try? JSONDecoder().decode(ThemeFile.self, from: data) else {
            return nil
        }
        guard (try? validateColors(themeFile.colors)) != nil else {
            return nil
        }

        let id = fileURL.deletingPathExtension().lastPathComponent
        return ThemeDefinition(
            id: id,
            name: themeFile.name,
            colorScheme: themeFile.colorScheme,
            colors: themeFile.colors,
            isBuiltIn: false,
            opacity: Self.clampOpacity(themeFile.opacity)
        )
    }

    static func clampOpacity(_ value: Double?) -> Double {
        guard let value else { return 1.0 }
        return max(0.5, min(value, 1.0))
    }

    private static let colorPattern = try! NSRegularExpression(
        pattern: #"^(#[0-9a-fA-F]{3,8}|rgba?\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*(,\s*[\d.]+\s*)?\))$"#
    )

    private func validateColors(_ colors: ThemeColors) throws {
        let values = [
            colors.bg, colors.fg, colors.muted, colors.border,
            colors.subtle, colors.surface, colors.accent,
            colors.mark, colors.currentMark
        ]
        for value in values {
            guard value.count <= 100 else {
                throw ThemeValidationError.invalidColor(value)
            }
            let range = NSRange(value.startIndex..., in: value)
            if Self.colorPattern.firstMatch(in: value, range: range) == nil {
                throw ThemeValidationError.invalidColor(value)
            }
        }
    }

    private func sanitizeFilename(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = String(name.unicodeScalars.filter { allowed.contains($0) })
        return sanitized.isEmpty ? "theme" : String(sanitized.prefix(64))
    }

    private func uniqueURL(for baseName: String, in directory: URL) -> URL {
        var candidate = directory.appendingPathComponent("\(baseName).json")
        var counter = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)-\(counter).json")
            counter += 1
        }
        return candidate
    }
}

enum ThemeValidationError: LocalizedError {
    case invalidColor(String)

    var errorDescription: String? {
        switch self {
        case .invalidColor(let value):
            "Invalid color value: \(value)"
        }
    }
}
