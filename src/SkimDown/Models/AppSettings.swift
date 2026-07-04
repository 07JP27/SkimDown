import Foundation

enum SidebarPosition: String, CaseIterable {
    case left
    case right
}

/// Application theme. In addition to the three built-ins, custom themes are
/// stored as `.custom(id:)` values loaded from `ColorScheme` files.
enum AppTheme: Equatable {
    case system
    case light
    case dark
    case custom(id: String)

    /// Built-in themes used by the fixed menu entries.
    static let builtInCases: [AppTheme] = [.system, .light, .dark]

    /// `UserDefaults` representation. Custom themes are stored as `custom:<id>`.
    var storageValue: String {
        switch self {
        case .system: return "system"
        case .light: return "light"
        case .dark: return "dark"
        case .custom(let id): return "custom:\(id)"
        }
    }

    /// Restores a theme from `UserDefaults`. Invalid values return nil.
    init?(storageValue: String) {
        switch storageValue {
        case "system": self = .system
        case "light": self = .light
        case "dark": self = .dark
        default:
            let prefix = "custom:"
            guard storageValue.hasPrefix(prefix) else { return nil }
            let id = String(storageValue.dropFirst(prefix.count))
            guard !id.isEmpty else { return nil }
            self = .custom(id: id)
        }
    }

    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }
}

struct AppSettings: Equatable {
    var sidebarPosition: SidebarPosition = .left
    var isSidebarVisible: Bool = true
    var sidebarWidth: Double = 260
    var isTableOfContentsVisible: Bool = true
    var theme: AppTheme = .system
    var fontSize: Double = 16
    var isSearchCaseSensitive: Bool = false
}
