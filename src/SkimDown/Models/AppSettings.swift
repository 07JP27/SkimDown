import Foundation

enum SidebarPosition: String, CaseIterable {
    case left
    case right
}

/// アプリのテーマ。組み込み3種類に加え、ユーザーが登録したカスタムカラースキーム
/// (`Models/ColorScheme.swift` を参照) を `.custom(id:)` として保持する。
enum AppTheme: Equatable {
    case system
    case light
    case dark
    case custom(id: String)

    /// 組み込みテーマ（メニューの固定3項目に対応）。
    static let builtInCases: [AppTheme] = [.system, .light, .dark]

    /// `UserDefaults` 用の文字列表現。`custom:<id>` 形式でカスタムテーマを表す。
    var storageValue: String {
        switch self {
        case .system: return "system"
        case .light: return "light"
        case .dark: return "dark"
        case .custom(let id): return "custom:\(id)"
        }
    }

    /// `UserDefaults` から復元する。不正値は `nil`。
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
    var theme: AppTheme = .system
    var fontSize: Double = 16
    var isSearchCaseSensitive: Bool = false
}
