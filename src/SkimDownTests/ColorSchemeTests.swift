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

    func testLoadReturnsNilForJSONCEndingWithComma() throws {
        let folder = try TemporaryFolder()
        let url = folder.url.appendingPathComponent("trailing-comma-end.json")
        try Data("{\"colors\": {\"editor.background\": \"#ffffff\",   ".utf8).write(to: url)
        XCTAssertNil(ColorScheme.load(from: url))
    }

    func testLoadDefaultsTypeToDarkWhenMissing() throws {
        let folder = try TemporaryFolder()
        let url = folder.url.appendingPathComponent("notype.json")
        try Data("{\"colors\":{}}".utf8).write(to: url)
        let scheme = try XCTUnwrap(ColorScheme.load(from: url))
        XCTAssertEqual(scheme.type, .dark)
    }

    func testLoadParsesVSCodeJSONCLineComments() throws {
        let folder = try TemporaryFolder()
        let json = """
        {
          // Theme Color reference.
          "$schema": "vscode://schemas/color-theme",
          "name": "Shades of Purple", // Display name
          "type": "dark",
          "colors": {
            // Editor colors.
            "editor.background": "#2D2B55", // Editor background color.
            "editor.foreground": "#FFFFFF"
          }
        }
        """
        let url = folder.url.appendingPathComponent("shades-of-purple-color-theme.json")
        try Data(json.utf8).write(to: url)

        let scheme = try XCTUnwrap(ColorScheme.load(from: url))
        XCTAssertEqual(scheme.displayName, "Shades of Purple")
        XCTAssertEqual(scheme.type, .dark)
        XCTAssertEqual(scheme.colors["editor.background"], "#2D2B55")
        XCTAssertEqual(scheme.colors["editor.foreground"], "#FFFFFF")
    }

    func testLoadParsesVSCodeJSONCBlockCommentsAndTrailingCommas() throws {
        let folder = try TemporaryFolder()
        let json = """
        {
          /* VS Code theme metadata. */
          "name": "Commented Theme",
          "type": "light",
          "colors": {
            "editor.background": "#ffffff",
            "editor.foreground": "#111111",
          },
          "tokenColors": [
            {
              "scope": "comment",
              "settings": {
                "foreground": "#888888",
              },
            },
          ],
        }
        """
        let url = folder.url.appendingPathComponent("commented.json")
        try Data(json.utf8).write(to: url)

        let scheme = try XCTUnwrap(ColorScheme.load(from: url))
        XCTAssertEqual(scheme.displayName, "Commented Theme")
        XCTAssertEqual(scheme.type, .light)
        XCTAssertEqual(scheme.colors["editor.background"], "#ffffff")
        XCTAssertEqual(scheme.colors["editor.foreground"], "#111111")
    }

    func testLoadPreservesCommentLikeTextInsideStrings() throws {
        let folder = try TemporaryFolder()
        let json = """
        {
          "name": "String Theme",
          "type": "dark",
          "colors": {
            "editor.background": "#111111",
            "textLink.foreground": "rgb(10, 20, 30)"
          },
          "metadata": {
            "homepage": "https://example.com/theme//not-a-comment",
            "escaped": "quote \\\" // still in string"
          }
        }
        """
        let url = folder.url.appendingPathComponent("string-theme.json")
        try Data(json.utf8).write(to: url)

        let scheme = try XCTUnwrap(ColorScheme.load(from: url))
        XCTAssertEqual(scheme.displayName, "String Theme")
        XCTAssertEqual(scheme.colors["textLink.foreground"], "rgb(10, 20, 30)")
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

    @MainActor
    func testHighlightCSSResourcePathFallsBackToSystemForUnresolvedCustomTheme() {
        XCTAssertEqual(
            MarkdownWebView.highlightCSSResourcePath(for: .custom(id: "missing"), resolvedTheme: nil),
            MarkdownWebView.highlightCSSResourcePath(for: .system, resolvedTheme: nil)
        )
    }

    func testCustomThemeSelectorMatchesDarkFallbackSpecificity() {
        XCTAssertEqual(
            MarkdownWebView.customThemeCSSSelector,
            #":root[data-theme="custom"][data-theme-type]"#
        )
    }
}