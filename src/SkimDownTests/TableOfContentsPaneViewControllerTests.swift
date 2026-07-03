import XCTest
@testable import SkimDown

@MainActor
final class TableOfContentsPaneViewControllerTests: XCTestCase {
    func testPreferredPaneHeightExpandsForLongTablesOfContents() {
        let controller = TableOfContentsPaneViewController()
        controller.loadViewIfNeeded()

        controller.update(items: makeItems(count: 20))

        XCTAssertGreaterThan(controller.preferredPaneHeight, 360)
    }

    func testPreferredPaneHeightKeepsShortTablesOfContentsCompact() {
        let controller = TableOfContentsPaneViewController()
        controller.loadViewIfNeeded()

        controller.update(items: makeItems(count: 2))

        XCTAssertLessThan(controller.preferredPaneHeight, 160)
    }

    private func makeItems(count: Int) -> [TableOfContentsItem] {
        (0..<count).map { index in
            TableOfContentsItem(level: 2, title: "Heading \(index + 1)", id: "heading-\(index + 1)")
        }
    }
}
