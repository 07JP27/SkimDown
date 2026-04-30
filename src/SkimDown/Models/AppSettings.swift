import Foundation

enum SidebarPosition: String, CaseIterable {
    case left
    case right
}

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark
}

struct AppSettings: Equatable {
    var sidebarPosition: SidebarPosition = .left
    var isSidebarVisible: Bool = true
    var sidebarWidth: Double = 260
    var theme: AppTheme = .system
    var fontSize: Double = 16
    var isSearchCaseSensitive: Bool = false
}

