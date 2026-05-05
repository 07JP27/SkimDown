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

    func testOpenFolderBookmarksRoundTrip() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.openFolderBookmarks.isEmpty)

        let bookmarkA = Data([0x01, 0x02, 0x03])
        let bookmarkB = Data([0x10, 0x20, 0x30, 0x40])
        store.openFolderBookmarks = [bookmarkA, bookmarkB]

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.openFolderBookmarks, [bookmarkA, bookmarkB])

        reloaded.openFolderBookmarks = []
        XCTAssertTrue(SettingsStore(defaults: defaults).openFolderBookmarks.isEmpty)
    }

    func testOpenFolderBookmarksAreIndependentOfRecentAndLast() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        let bookmark = Data([0xAA, 0xBB])
        store.recordRecentFolderBookmark(bookmark)

        XCTAssertEqual(store.lastFolderBookmark, bookmark)
        XCTAssertEqual(store.recentFolderBookmarks, [bookmark])
        XCTAssertTrue(store.openFolderBookmarks.isEmpty,
                      "Recording a recent bookmark must not implicitly add it to openFolderBookmarks")
        XCTAssertTrue(store.openFolderStates.isEmpty,
                      "Recording a recent bookmark must not implicitly add it to openFolderStates")
    }

    func testOpenFolderStatesRoundTripPreservesFrames() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.openFolderStates.isEmpty)

        let stateA = OpenFolderState(
            bookmark: Data([0x01, 0x02]),
            frame: CGRect(x: 100, y: 200, width: 1024, height: 768),
            sidebarWidth: 300
        )
        let stateB = OpenFolderState(
            bookmark: Data([0x03, 0x04]),
            frame: CGRect(x: -50, y: 0, width: 960, height: 660),
            sidebarWidth: 220
        )
        store.openFolderStates = [stateA, stateB]

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.openFolderStates, [stateA, stateB])
        XCTAssertEqual(reloaded.openFolderStates[0].sidebarWidth, 300)
        XCTAssertEqual(reloaded.openFolderStates[1].sidebarWidth, 220)
    }

    func testWritingOpenFolderStatesClearsLegacyBookmarksKey() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        store.openFolderBookmarks = [Data([0x10]), Data([0x20])]
        XCTAssertEqual(store.openFolderBookmarks.count, 2)

        store.openFolderStates = [
            OpenFolderState(bookmark: Data([0x10]), frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        ]

        XCTAssertTrue(store.openFolderBookmarks.isEmpty,
                      "Writing openFolderStates must clear the legacy openFolderBookmarks key")
        XCTAssertEqual(store.openFolderStates.count, 1)
    }

    func testOpenFolderStatesMigratesFromLegacyBookmarksWithZeroFrame() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let legacyA = Data([0xAA])
        let legacyB = Data([0xBB])
        let store = SettingsStore(defaults: defaults)
        store.openFolderBookmarks = [legacyA, legacyB]

        let migrated = store.openFolderStates
        XCTAssertEqual(migrated.map(\.bookmark), [legacyA, legacyB])
        XCTAssertTrue(migrated.allSatisfy { $0.frame == .zero },
                      "Legacy bookmarks have no frame and should migrate as .zero")
    }
}

