import XCTest
@testable import SkimDown

final class MarkdownWebViewTests: XCTestCase {
    @MainActor
    func testReservedTrailingWidthNormalizationKeepsFinitePositiveValues() {
        XCTAssertEqual(MarkdownWebView.normalizedReservedTrailingWidth(300), 300)
    }

    @MainActor
    func testReservedTrailingWidthNormalizationClampsNegativeValues() {
        XCTAssertEqual(MarkdownWebView.normalizedReservedTrailingWidth(-42), 0)
    }

    @MainActor
    func testReservedTrailingWidthNormalizationRejectsNaN() {
        XCTAssertEqual(MarkdownWebView.normalizedReservedTrailingWidth(.nan), 0)
    }

    @MainActor
    func testReservedTrailingWidthNormalizationRejectsInfinities() {
        XCTAssertEqual(MarkdownWebView.normalizedReservedTrailingWidth(.infinity), 0)
        XCTAssertEqual(MarkdownWebView.normalizedReservedTrailingWidth(-.infinity), 0)
    }
}
