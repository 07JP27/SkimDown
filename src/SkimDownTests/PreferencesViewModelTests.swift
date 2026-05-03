import XCTest
@testable import SkimDown

@MainActor
final class PreferencesViewModelTests: XCTestCase {
    func testPropertyChangesArePersisted() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        let vm = PreferencesViewModel(settingsStore: store, themeStore: ThemeStore())

        vm.theme = .dark
        XCTAssertEqual(store.theme, .dark)

        vm.fontSize = 20
        XCTAssertEqual(store.fontSize, 20)

        vm.fontFamily = "Menlo-Regular"
        XCTAssertEqual(store.fontFamily, "Menlo-Regular")

        vm.sidebarPosition = .right
        XCTAssertEqual(store.sidebarPosition, .right)
    }

    func testResetFontSizeRestoresDefault() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        let vm = PreferencesViewModel(settingsStore: store, themeStore: ThemeStore())

        vm.fontSize = 22
        XCTAssertEqual(store.fontSize, 22)

        vm.resetFontSize()
        XCTAssertEqual(vm.fontSize, 16)
        XCTAssertEqual(store.fontSize, 16)
    }

    func testResetFontFamilyRestoresNil() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        let vm = PreferencesViewModel(settingsStore: store, themeStore: ThemeStore())

        vm.fontFamily = "Courier"
        XCTAssertEqual(store.fontFamily, "Courier")

        vm.resetFontFamily()
        XCTAssertNil(vm.fontFamily)
        XCTAssertNil(store.fontFamily)
    }

    func testClearRecentFolders() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        store.recordRecentFolderBookmark(Data([0x01, 0x02]))
        XCTAssertFalse(store.recentFolderBookmarks.isEmpty)
        XCTAssertNotNil(store.lastFolderBookmark)

        let vm = PreferencesViewModel(settingsStore: store, themeStore: ThemeStore())
        vm.clearRecentFolders()

        XCTAssertTrue(store.recentFolderBookmarks.isEmpty)
        XCTAssertNil(store.lastFolderBookmark)
    }

    func testReloadFromStore() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        let vm = PreferencesViewModel(settingsStore: store, themeStore: ThemeStore())

        store.theme = .light
        store.fontSize = 24
        store.fontFamily = "Georgia"
        store.sidebarPosition = .right

        vm.reloadFromStore()

        XCTAssertEqual(vm.theme, .light)
        XCTAssertEqual(vm.fontSize, 24)
        XCTAssertEqual(vm.fontFamily, "Georgia")
        XCTAssertEqual(vm.sidebarPosition, .right)
    }
}
