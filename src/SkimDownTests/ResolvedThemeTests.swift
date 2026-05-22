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
        XCTAssertEqual(values["--skimdown-border"], "#333333")
        XCTAssertEqual(values["--skimdown-current-mark"], "#515c6a")
        XCTAssertEqual(values["--skimdown-mark"], "#ea5c00")
    }

    func testResolveAppliesDarkFallbackWhenKeyIsMissing() {
        let scheme = ColorScheme(id: "test", displayName: "Test", type: .dark, colors: [:])
        let resolved = ResolvedTheme.resolve(from: scheme)
        let values = Dictionary(uniqueKeysWithValues: resolved.cssVariables.map { ($0.name, $0.value) })
        // Dark fallback values from ResolvedTheme.swift.
        XCTAssertEqual(values["--skimdown-bg"], "#0f1116")
        XCTAssertEqual(values["--skimdown-fg"], "#e8ebf1")
    }

    func testResolveAppliesLightFallbackWhenKeyIsMissing() {
        let scheme = ColorScheme(id: "test", displayName: "Test", type: .light, colors: [:])
        let resolved = ResolvedTheme.resolve(from: scheme)
        let values = Dictionary(uniqueKeysWithValues: resolved.cssVariables.map { ($0.name, $0.value) })
        // Light fallback values.
        XCTAssertEqual(values["--skimdown-bg"], "#fbfbfd")
        XCTAssertEqual(values["--skimdown-fg"], "#20242c")
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
}
