import AppKit

/// VS Code-style Git decorations for the Markdown tree.
enum GitTreeDecoration {
    /// Aggregates file statuses into their ancestor folders. Modified wins over added,
    /// and added wins over untracked.
    static func folderStatuses(for fileStatuses: [String: GitFileStatus]) -> [String: GitFileStatus] {
        var folderStatuses: [String: GitFileStatus] = [:]
        for (relativePath, status) in fileStatuses {
            var components = relativePath.split(separator: "/").dropLast()
            while !components.isEmpty {
                let folderPath = components.joined(separator: "/")
                if let existing = folderStatuses[folderPath], priority(existing) >= priority(status) {
                    break
                }
                folderStatuses[folderPath] = status
                components.removeLast()
            }
        }
        return folderStatuses
    }

    static func badge(for status: GitFileStatus) -> String {
        switch status {
        case .modified: "M"
        case .untracked: "U"
        case .added: "A"
        }
    }

    static func accessibilityDescription(for status: GitFileStatus) -> String {
        switch status {
        case .modified: "Modified"
        case .untracked: "Untracked"
        case .added: "Added"
        }
    }

    static func color(for status: GitFileStatus) -> NSColor {
        switch status {
        case .modified:
            dynamicColor(light: 0x895503, dark: 0xE2C08D)
        case .untracked:
            dynamicColor(light: 0x007100, dark: 0x73C991)
        case .added:
            dynamicColor(light: 0x587C0C, dark: 0x81B88B)
        }
    }

    private static func priority(_ status: GitFileStatus) -> Int {
        switch status {
        case .modified: 2
        case .added: 1
        case .untracked: 0
        }
    }

    private static func dynamicColor(light: Int, dark: Int) -> NSColor {
        NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }
    }
}
