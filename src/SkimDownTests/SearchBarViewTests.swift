import AppKit
import XCTest
@testable import SkimDown

final class SearchBarViewTests: XCTestCase {
    @MainActor
    func testAppearanceChangePropagatesToSearchField() throws {
        let searchBar = SearchBarView(frame: NSRect(x: 0, y: 0, width: 320, height: 44))
        searchBar.appearance = try XCTUnwrap(NSAppearance(named: .darkAqua))

        searchBar.viewDidChangeEffectiveAppearance()

        let searchField = try XCTUnwrap(searchBar.firstSubview(ofType: NSSearchField.self))
        XCTAssertEqual(searchField.appearance?.name, .darkAqua)
    }
}

private extension NSView {
    func firstSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let matchingView = self as? T {
            return matchingView
        }

        for subview in subviews {
            if let matchingView = subview.firstSubview(ofType: type) {
                return matchingView
            }
        }

        return nil
    }
}
