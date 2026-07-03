import XCTest
@testable import SkimDown

final class ResolvedThemeTests: XCTestCase {
    func testResolveMapsCommonVSCodeKeysToCSSVariables() {
        let scheme = ColorScheme(
            id: "test",
            displayName: "Test",
            type: .dark,
            colors: [
                "editor.background": "#1e1e1e",
                "editor.foreground": "#d4d4d4",
                "descriptionForeground": "#9da5b4",
                "textLink.foreground": "#3794ff",
                "panel.border": "#333333",
                "editor.findMatchBackground": "#515c6a",
                "editor.findMatchHighlightBackground": "#ea5c00"
            ]
        )

        let resolved = ResolvedTheme.resolve(from: scheme)
        XCTAssertEqual(resolved.id, "test")
        XCTAssertEqual(resolved.type, .dark)
        XCTAssertTrue(resolved.isDark)

        let values = Dictionary(uniqueKeysWithValues: resolved.cssVariables.map { ($0.name, $0.value) })
        XCTAssertEqual(values["--skimdown-bg"], "#1e1e1e")
        XCTAssertEqual(values["--skimdown-fg"], "#d4d4d4")
        XCTAssertEqual(values["--skimdown-accent"], "#3794ff")
        XCTAssertEqual(values["--skimdown-diagram-line"], "#9da5b4")
        XCTAssertEqual(values["--skimdown-border"], "#333333")
        XCTAssertEqual(values["--skimdown-current-mark"], "#515c6a")
        XCTAssertEqual(values["--skimdown-mark"], "#ea5c00")
        XCTAssertEqual(resolved.tableOfContentsBackgroundColor, "#090b0d")
    }

    func testResolveAppliesDarkFallbackWhenKeyIsMissing() {
        let scheme = ColorScheme(id: "test", displayName: "Test", type: .dark, colors: [:])
        let resolved = ResolvedTheme.resolve(from: scheme)
        let values = Dictionary(uniqueKeysWithValues: resolved.cssVariables.map { ($0.name, $0.value) })
        // Dark fallback values from ResolvedTheme.swift.
        XCTAssertEqual(values["--skimdown-bg"], "#0f1116")
        XCTAssertEqual(values["--skimdown-fg"], "#e8ebf1")
        XCTAssertEqual(values["--skimdown-diagram-line"], "#8b94a3")
        XCTAssertEqual(resolved.tableOfContentsBackgroundColor, "#090b0d")
    }

    func testResolveAppliesLightFallbackWhenKeyIsMissing() {
        let scheme = ColorScheme(id: "test", displayName: "Test", type: .light, colors: [:])
        let resolved = ResolvedTheme.resolve(from: scheme)
        let values = Dictionary(uniqueKeysWithValues: resolved.cssVariables.map { ($0.name, $0.value) })
        // Light fallback values.
        XCTAssertEqual(values["--skimdown-bg"], "#fbfbfd")
        XCTAssertEqual(values["--skimdown-fg"], "#20242c")
        XCTAssertEqual(values["--skimdown-diagram-line"], "#69707d")
        XCTAssertEqual(resolved.tableOfContentsBackgroundColor, "#f0f0f2")
        XCTAssertFalse(resolved.isDark)
    }

    func testResolvePrefersHigherPriorityKeyWhenMultiplePresent() {
        let scheme = ColorScheme(
            id: "test",
            displayName: "Test",
            type: .light,
            colors: [
                "panel.border": "#aaaaaa",
                "editorGroup.border": "#bbbbbb",
                "editorWidget.border": "#cccccc"
            ]
        )
        let resolved = ResolvedTheme.resolve(from: scheme)
        let values = Dictionary(uniqueKeysWithValues: resolved.cssVariables.map { ($0.name, $0.value) })
        // panel.border has the highest priority for --skimdown-border.
        XCTAssertEqual(values["--skimdown-border"], "#aaaaaa")
    }

    func testResolveRejectsUnsafeColorValuesAndFallsBack() {
        let scheme = ColorScheme(
            id: "test",
            displayName: "Test",
            type: .light,
            colors: [
                "editor.background": "#ffffff; } body { background: red",
                "editor.foreground": "url(https://example.com/tracker)",
                "textLink.foreground": "rgb(10, 20, 30)"
            ]
        )

        let resolved = ResolvedTheme.resolve(from: scheme)
        let values = Dictionary(uniqueKeysWithValues: resolved.cssVariables.map { ($0.name, $0.value) })

        XCTAssertEqual(values["--skimdown-bg"], "#fbfbfd")
        XCTAssertEqual(values["--skimdown-fg"], "#20242c")
        XCTAssertEqual(values["--skimdown-accent"], "rgb(10, 20, 30)")
    }

    func testResolveAcceptsVSCodeHexAlphaColor() {
        let scheme = ColorScheme(
            id: "test",
            displayName: "Test",
            type: .dark,
            colors: [
                "editor.findMatchBackground": "#515c6aaa"
            ]
        )

        let resolved = ResolvedTheme.resolve(from: scheme)
        let values = Dictionary(uniqueKeysWithValues: resolved.cssVariables.map { ($0.name, $0.value) })

        XCTAssertEqual(values["--skimdown-current-mark"], "#515c6aaa")
    }

    func testResolvePrefersDedicatedTableOfContentsBackgroundKey() {
        let scheme = ColorScheme(
            id: "test",
            displayName: "Test",
            type: .dark,
            colors: [
                "skimdown.tableOfContents.background": "#101820",
                "sideBar.background": "#202a36",
                "editorWidget.background": "#303a46"
            ]
        )

        let resolved = ResolvedTheme.resolve(from: scheme)

        XCTAssertEqual(resolved.tableOfContentsBackgroundColor, "#101820")
    }

    func testResolveUsesSidebarBackgroundForTableOfContentsBackground() {
        let scheme = ColorScheme(
            id: "test",
            displayName: "Test",
            type: .light,
            colors: [
                "sideBar.background": "#eef0f4",
                "editorWidget.background": "#f8f9fb"
            ]
        )

        let resolved = ResolvedTheme.resolve(from: scheme)

        XCTAssertEqual(resolved.tableOfContentsBackgroundColor, "#eef0f4")
    }

    func testResolveUsesEditorWidgetBackgroundForTableOfContentsBackgroundFallback() {
        let scheme = ColorScheme(
            id: "test",
            displayName: "Test",
            type: .light,
            colors: [
                "editorWidget.background": "#f8f9fb"
            ]
        )

        let resolved = ResolvedTheme.resolve(from: scheme)

        XCTAssertEqual(resolved.tableOfContentsBackgroundColor, "#f8f9fb")
    }

    func testResolveRejectsUnsupportedNativeTableOfContentsBackgroundAndFallsBack() {
        let scheme = ColorScheme(
            id: "test",
            displayName: "Test",
            type: .dark,
            colors: [
                "skimdown.tableOfContents.background": "rgb(10, 20, 30)",
                "sideBar.background": "transparent",
                "editorWidget.background": "#1a1f25"
            ]
        )

        let resolved = ResolvedTheme.resolve(from: scheme)

        XCTAssertEqual(resolved.tableOfContentsBackgroundColor, "#1a1f25")
    }
}
