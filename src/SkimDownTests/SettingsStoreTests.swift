import XCTest
@testable import SkimDown

final class SettingsStoreTests: XCTestCase {
    func testDefaultsAndPersistence() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings, AppSettings())

        store.sidebarPosition = .right
        store.isSidebarVisible = false
        store.sidebarWidth = 320
        store.theme = .dark
        store.fontSize = 18
        store.isSearchCaseSensitive = true

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.sidebarPosition, .right)
        XCTAssertFalse(reloaded.isSidebarVisible)
        XCTAssertEqual(reloaded.sidebarWidth, 320)
        XCTAssertEqual(reloaded.theme, .dark)
        XCTAssertEqual(reloaded.fontSize, 18)
        XCTAssertTrue(reloaded.isSearchCaseSensitive)
    }

    func testPerFolderLastSelectionAndExpandedPaths() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let folder = try TemporaryFolder()
        try folder.write("doc", to: "Docs/doc.md")
        let file = folder.url.appendingPathComponent("Docs/doc.md")
        let store = SettingsStore(defaults: defaults)

        store.setLastSelectedMarkdown(file, for: folder.url)
        store.setExpandedTreeItemRelativePaths(["Docs"], for: folder.url)

        XCTAssertEqual(store.lastSelectedMarkdownRelativePath(for: folder.url), "Docs/doc.md")
        XCTAssertEqual(store.expandedTreeItemRelativePaths(for: folder.url), ["Docs"])
    }
}

