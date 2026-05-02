import AppKit
import Combine
import UniformTypeIdentifiers

extension Notification.Name {
    static let skimDownSettingsDidChange = Notification.Name("SkimDownSettingsDidChange")
}

@MainActor
final class PreferencesViewModel: ObservableObject {
    private let settingsStore: SettingsStore
    let themeStore: ThemeStore

    @Published var theme: AppTheme
    @Published var customThemeID: String?
    @Published var fontFamily: String?
    @Published var fontSize: Double
    @Published var sidebarPosition: SidebarPosition

    private var cancellables: Set<AnyCancellable> = []

    init(settingsStore: SettingsStore, themeStore: ThemeStore) {
        self.settingsStore = settingsStore
        self.themeStore = themeStore
        self.theme = settingsStore.theme
        self.customThemeID = settingsStore.customThemeID
        self.fontFamily = settingsStore.fontFamily
        self.fontSize = settingsStore.fontSize
        self.sidebarPosition = settingsStore.sidebarPosition

        $theme
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] value in
                self?.settingsStore.theme = value
                self?.postSettingsChanged()
            }
            .store(in: &cancellables)

        $customThemeID
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] value in
                self?.settingsStore.customThemeID = value
                self?.postSettingsChanged()
            }
            .store(in: &cancellables)

        $fontFamily
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] value in
                self?.settingsStore.fontFamily = value
                self?.postSettingsChanged()
            }
            .store(in: &cancellables)

        $fontSize
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] value in
                self?.settingsStore.fontSize = value
                self?.postSettingsChanged()
            }
            .store(in: &cancellables)

        $sidebarPosition
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] value in
                self?.settingsStore.sidebarPosition = value
                self?.postSettingsChanged()
            }
            .store(in: &cancellables)
    }

    var fontDisplayName: String {
        if let fontFamily, let font = NSFont(name: fontFamily, size: fontSize) {
            return font.displayName ?? fontFamily
        }
        return "System Default"
    }

    var availableThemes: [ThemeDefinition] {
        themeStore.themes
    }

    var selectedTheme: ThemeDefinition? {
        guard let id = customThemeID else { return nil }
        return themeStore.theme(for: id)
    }

    func selectTheme(_ theme: ThemeDefinition?) {
        customThemeID = theme?.id
    }

    func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a theme JSON file"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let imported = try themeStore.importTheme(from: url)
            customThemeID = imported.id
            objectWillChange.send()
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    func deleteTheme(_ theme: ThemeDefinition) {
        guard !theme.isBuiltIn else { return }
        if customThemeID == theme.id {
            customThemeID = nil
        }
        try? themeStore.deleteTheme(id: theme.id)
        objectWillChange.send()
    }

    func revealThemesFolder() {
        let url = themeStore.themesDirectoryURL
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        }
    }

    func resetFontSize() {
        fontSize = 16
    }

    func resetFontFamily() {
        fontFamily = nil
    }

    func clearRecentFolders() {
        settingsStore.recentFolderBookmarks = []
        settingsStore.lastFolderBookmark = nil
    }

    func reloadFromStore() {
        theme = settingsStore.theme
        customThemeID = settingsStore.customThemeID
        fontFamily = settingsStore.fontFamily
        fontSize = settingsStore.fontSize
        sidebarPosition = settingsStore.sidebarPosition
    }

    private func postSettingsChanged() {
        NotificationCenter.default.post(name: .skimDownSettingsDidChange, object: nil)
    }
}
