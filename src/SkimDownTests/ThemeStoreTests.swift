import XCTest
@testable import SkimDown

final class ThemeStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testBuiltInThemesAlwaysPresent() {
        let store = ThemeStore()
        XCTAssertNotNil(store.theme(for: "builtin-light"))
        XCTAssertNotNil(store.theme(for: "builtin-dark"))
        XCTAssertTrue(store.themes.count >= 2)
    }

    func testImportAndDeleteTheme() throws {
        let json = """
        {
            "name": "Test Theme",
            "colorScheme": "light",
            "colors": {
                "bg": "#ffffff",
                "fg": "#000000",
                "muted": "#666666",
                "border": "#cccccc",
                "subtle": "#f0f0f0",
                "surface": "#fafafa",
                "accent": "#0066cc",
                "mark": "#ffff00",
                "currentMark": "#ffcc00"
            }
        }
        """
        let fileURL = tempDir.appendingPathComponent("test-theme.json")
        try json.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = ThemeStore()
        let imported = try store.importTheme(from: fileURL)

        XCTAssertEqual(imported.name, "Test Theme")
        XCTAssertEqual(imported.colorScheme, .light)
        XCTAssertFalse(imported.isBuiltIn)
        XCTAssertNotNil(store.theme(for: imported.id))

        try store.deleteTheme(id: imported.id)
        XCTAssertNil(store.theme(for: imported.id))
    }

    func testCannotDeleteBuiltInTheme() throws {
        let store = ThemeStore()
        try store.deleteTheme(id: "builtin-light")
        XCTAssertNotNil(store.theme(for: "builtin-light"))
    }

    func testRejectsInvalidColorValues() throws {
        let json = """
        {
            "name": "Bad Theme",
            "colorScheme": "dark",
            "colors": {
                "bg": "not-a-color",
                "fg": "#000000",
                "muted": "#666666",
                "border": "#cccccc",
                "subtle": "#f0f0f0",
                "surface": "#fafafa",
                "accent": "#0066cc",
                "mark": "#ffff00",
                "currentMark": "#ffcc00"
            }
        }
        """
        let fileURL = tempDir.appendingPathComponent("bad-theme.json")
        try json.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = ThemeStore()
        XCTAssertThrowsError(try store.importTheme(from: fileURL))
    }

    func testCSSVariablesMapping() {
        let colors = ThemeColors(
            bg: "#fff", fg: "#000", muted: "#999",
            border: "#ccc", subtle: "#f0f0f0", surface: "#fafafa",
            accent: "#06c", mark: "#ff0", currentMark: "#fc0"
        )
        let vars = colors.cssVariables
        XCTAssertEqual(vars["--skimdown-bg"], "#fff")
        XCTAssertEqual(vars["--skimdown-fg"], "#000")
        XCTAssertEqual(vars["--skimdown-accent"], "#06c")
        XCTAssertEqual(vars.count, 9)
    }
}
