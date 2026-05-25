import XCTest
@testable import SkimDown

final class ColorSchemeTests: XCTestCase {
    func testLoadParsesNameTypeAndColors() throws {
        let folder = try TemporaryFolder()
        let json = """
        {
          "name": "My Theme",
          "type": "dark",
          "colors": {
            "editor.background": "#1e1e1e",
            "editor.foreground": "#d4d4d4",
            "textLink.foreground": "#3794ff",
            "ignored": 42
          }
        }
        """
        let url = folder.url.appendingPathComponent("my-theme.json")
        try json.data(using: .utf8)!.write(to: url)

        let scheme = try XCTUnwrap(ColorScheme.load(from: url))
        XCTAssertEqual(scheme.id, "my-theme")
        XCTAssertEqual(scheme.displayName, "My Theme")
        XCTAssertEqual(scheme.type, .dark)
        XCTAssertEqual(scheme.colors["editor.background"], "#1e1e1e")
        XCTAssertEqual(scheme.colors["editor.foreground"], "#d4d4d4")
        XCTAssertEqual(scheme.colors["textLink.foreground"], "#3794ff")
        XCTAssertNil(scheme.colors["ignored"], "Non-string color entries should be dropped")
    }

    func testLoadFallsBackToFileNameAsDisplayName() throws {
        let folder = try TemporaryFolder()
        let url = folder.url.appendingPathComponent("anonymous.json")
        try Data("{\"type\":\"light\",\"colors\":{}}".utf8).write(to: url)

        let scheme = try XCTUnwrap(ColorScheme.load(from: url))
        XCTAssertEqual(scheme.id, "anonymous")
        XCTAssertEqual(scheme.displayName, "anonymous")
        XCTAssertEqual(scheme.type, .light)
    }

    func testLoadReturnsNilForInvalidJSON() throws {
        let folder = try TemporaryFolder()
        let url = folder.url.appendingPathComponent("broken.json")
        try Data("{not valid json".utf8).write(to: url)
        XCTAssertNil(ColorScheme.load(from: url))
    }

    func testLoadDefaultsTypeToDarkWhenMissing() throws {
        let folder = try TemporaryFolder()
        let url = folder.url.appendingPathComponent("notype.json")
        try Data("{\"colors\":{}}".utf8).write(to: url)
        let scheme = try XCTUnwrap(ColorScheme.load(from: url))
        XCTAssertEqual(scheme.type, .dark)
    }

    @MainActor
    func testHighlightCSSResourcePathUsesBuiltInThemeType() {
        XCTAssertEqual(
            MarkdownWebView.highlightCSSResourcePath(for: .light, resolvedTheme: nil),
            "vendor/highlight.js/github.min.css"
        )
        XCTAssertEqual(
            MarkdownWebView.highlightCSSResourcePath(for: .dark, resolvedTheme: nil),
            "vendor/highlight.js/github-dark.min.css"
        )
    }

    @MainActor
    func testHighlightCSSResourcePathUsesCustomThemeType() {
        let lightTheme = ResolvedTheme.resolve(from: ColorScheme(id: "light", displayName: "Light", type: .light, colors: [:]))
        let darkTheme = ResolvedTheme.resolve(from: ColorScheme(id: "dark", displayName: "Dark", type: .dark, colors: [:]))

        XCTAssertEqual(
            MarkdownWebView.highlightCSSResourcePath(for: .custom(id: "light"), resolvedTheme: lightTheme),
            "vendor/highlight.js/github.min.css"
        )
        XCTAssertEqual(
            MarkdownWebView.highlightCSSResourcePath(for: .custom(id: "dark"), resolvedTheme: darkTheme),
            "vendor/highlight.js/github-dark.min.css"
        )
    }
}
