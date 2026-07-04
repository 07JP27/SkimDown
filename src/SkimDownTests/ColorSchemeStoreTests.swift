import XCTest
@testable import SkimDown

@MainActor
final class ColorSchemeStoreTests: XCTestCase {
    func testReloadDiscoversJSONFilesAndSortsByDisplayName() throws {
        let folder = try TemporaryFolder()
        try write(name: "zeta.json", json: "{\"name\":\"Zulu\",\"type\":\"dark\",\"colors\":{}}", in: folder.url)
        try write(name: "alpha.json", json: "{\"name\":\"Alpha\",\"type\":\"light\",\"colors\":{}}", in: folder.url)

        let store = ColorSchemeStore(themesDirectoryURL: folder.url)
        let schemes = store.reload()

        XCTAssertEqual(schemes.map(\.displayName), ["Alpha", "Zulu"])
    }

    func testReloadSkipsInvalidJSON() throws {
        let folder = try TemporaryFolder()
        try write(name: "good.json", json: "{\"name\":\"Good\",\"type\":\"dark\",\"colors\":{}}", in: folder.url)
        try write(name: "bad.json", json: "this is not json", in: folder.url)

        let store = ColorSchemeStore(themesDirectoryURL: folder.url)
        let schemes = store.reload()
        XCTAssertEqual(schemes.map(\.id), ["good"])
    }

    func testResolvedThemeReturnsNilForBuiltIns() throws {
        let folder = try TemporaryFolder()
        let store = ColorSchemeStore(themesDirectoryURL: folder.url)
        store.reload()
        XCTAssertNil(store.resolvedTheme(for: .system))
        XCTAssertNil(store.resolvedTheme(for: .light))
        XCTAssertNil(store.resolvedTheme(for: .dark))
    }

    func testResolvedThemeReturnsResolvedSchemeForCustom() throws {
        let folder = try TemporaryFolder()
        try write(
            name: "monokai.json",
            json: "{\"name\":\"Monokai\",\"type\":\"dark\",\"colors\":{\"editor.background\":\"#272822\"}}",
            in: folder.url
        )

        let store = ColorSchemeStore(themesDirectoryURL: folder.url)
        store.reload()

        let resolved = try XCTUnwrap(store.resolvedTheme(for: .custom(id: "monokai")))
        XCTAssertEqual(resolved.id, "monokai")
        XCTAssertEqual(resolved.displayName, "Monokai")
        XCTAssertTrue(resolved.isDark)
        XCTAssertTrue(resolved.cssVariables.contains(where: { $0.name == "--skimdown-bg" && $0.value == "#272822" }))
    }

    func testResolvedThemeReturnsNilForUnknownCustomID() throws {
        let folder = try TemporaryFolder()
        let store = ColorSchemeStore(themesDirectoryURL: folder.url)
        store.reload()
        XCTAssertNil(store.resolvedTheme(for: .custom(id: "missing")))
    }

    func testNormalizedThemeFallsBackToSystemForMissingCustomTheme() throws {
        let folder = try TemporaryFolder()
        let store = ColorSchemeStore(themesDirectoryURL: folder.url)
        store.reload()

        XCTAssertEqual(store.normalizedTheme(.custom(id: "missing")), .system)
        XCTAssertEqual(store.normalizedTheme(.dark), .dark)
    }

    func testNormalizedThemePreservesExistingCustomTheme() throws {
        let folder = try TemporaryFolder()
        try write(
            name: "monokai.json",
            json: "{\"name\":\"Monokai\",\"type\":\"dark\",\"colors\":{\"editor.background\":\"#272822\"}}",
            in: folder.url
        )

        let store = ColorSchemeStore(themesDirectoryURL: folder.url)
        store.reload()

        XCTAssertEqual(store.normalizedTheme(.custom(id: "monokai")), .custom(id: "monokai"))
    }

    func testEnsureDirectoryExistsCreatesFolder() throws {
        let parent = try TemporaryFolder()
        let target = parent.url.appendingPathComponent("Themes", isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))

        let store = ColorSchemeStore(themesDirectoryURL: target)
        store.ensureDirectoryExists()
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
    }

    func testEnsureDirectoryExistsDoesNotReplaceFileAtTargetPath() throws {
        let parent = try TemporaryFolder()
        let target = parent.url.appendingPathComponent("Themes", isDirectory: true)
        try Data("not a directory".utf8).write(to: target)

        let store = ColorSchemeStore(themesDirectoryURL: target)
        XCTAssertTrue(store.reload().isEmpty)

        var isDirectory: ObjCBool = true
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory))
        XCTAssertFalse(isDirectory.boolValue)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "not a directory")
    }

    func testReloadIgnoresNonRegularJSONEntries() throws {
        let folder = try TemporaryFolder()
        try write(name: "good.json", json: "{\"name\":\"Good\",\"type\":\"dark\",\"colors\":{}}", in: folder.url)
        try FileManager.default.createDirectory(
            at: folder.url.appendingPathComponent("directory.json", isDirectory: true),
            withIntermediateDirectories: false
        )
        let linkedTarget = folder.url.appendingPathComponent("linked-target.txt")
        try Data("{\"name\":\"Linked\",\"type\":\"dark\",\"colors\":{}}".utf8).write(to: linkedTarget)
        try FileManager.default.createSymbolicLink(
            at: folder.url.appendingPathComponent("linked.json"),
            withDestinationURL: linkedTarget
        )

        let store = ColorSchemeStore(themesDirectoryURL: folder.url)
        let schemes = store.reload()

        XCTAssertEqual(schemes.map(\.id), ["good"])
    }

    private func write(name: String, json: String, in folderURL: URL) throws {
        let url = folderURL.appendingPathComponent(name)
        try Data(json.utf8).write(to: url)
    }
}

@MainActor
final class AppThemeStorageTests: XCTestCase {
    func testStorageValueRoundTripForBuiltIns() {
        XCTAssertEqual(AppTheme(storageValue: "system"), .system)
        XCTAssertEqual(AppTheme(storageValue: "light"), .light)
        XCTAssertEqual(AppTheme(storageValue: "dark"), .dark)
        XCTAssertEqual(AppTheme.system.storageValue, "system")
        XCTAssertEqual(AppTheme.light.storageValue, "light")
        XCTAssertEqual(AppTheme.dark.storageValue, "dark")
    }

    func testStorageValueRoundTripForCustom() {
        let theme = AppTheme.custom(id: "my-theme")
        XCTAssertEqual(theme.storageValue, "custom:my-theme")
        XCTAssertEqual(AppTheme(storageValue: "custom:my-theme"), theme)
    }

    func testStorageValueRejectsEmptyCustomID() {
        XCTAssertNil(AppTheme(storageValue: "custom:"))
    }

    func testStorageValueRejectsUnknownPrefix() {
        XCTAssertNil(AppTheme(storageValue: "anything"))
        XCTAssertNil(AppTheme(storageValue: ""))
    }

    func testSettingsStorePersistsCustomTheme() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.theme = .custom(id: "monokai")

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.theme, .custom(id: "monokai"))
    }

    func testSettingsStoreFallsBackToSystemForInvalidStorage() throws {
        let suiteName = "dev.jp27.SkimDownTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("garbage-value", forKey: "theme")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.theme, .system)
    }
}
