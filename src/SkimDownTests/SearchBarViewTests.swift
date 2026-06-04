import AppKit
import XCTest
@testable import SkimDown

final class SearchBarViewTests: XCTestCase {
    @MainActor
    func testAppearanceChangePropagatesToSearchField() throws {
        let searchBar = SearchBarView(frame: NSRect(x: 0, y: 0, width: 320, height: 44))
        searchBar.appearance = try XCTUnwrap(NSAppearance(named: .darkAqua))

        searchBar.viewDidChangeEffectiveAppearance()

        let stack = try XCTUnwrap(searchBar.subviews.compactMap { $0 as? NSStackView }.first)
        let searchField = try XCTUnwrap(stack.arrangedSubviews.compactMap { $0 as? NSSearchField }.first)
        XCTAssertEqual(searchField.appearance?.name, .darkAqua)
    }
}
