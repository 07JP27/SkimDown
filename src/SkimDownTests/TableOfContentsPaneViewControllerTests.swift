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

    func testPreferredListHeightLeavesSlackForScrollViewFitting() {
        XCTAssertEqual(
            TableOfContentsPaneViewController.preferredListHeight(
                rowCount: 2,
                rowHeight: 24,
                intercellSpacing: 2
            ),
            60
        )
    }

    func testResolvedPaneHeightUsesAvailableHeightForOverflowingContent() {
        let height = TableOfContentsPaneViewController.resolvedPaneHeight(
            preferredHeight: 640,
            availableHeight: 520
        )

        XCTAssertEqual(height, 520)
    }

    func testResolvedPaneHeightKeepsCompactContentAtPreferredHeight() {
        let height = TableOfContentsPaneViewController.resolvedPaneHeight(
            preferredHeight: 120,
            availableHeight: 520
        )

        XCTAssertEqual(height, 120)
    }

    func testResolvedPaneHeightFallsBackToPreferredHeightBeforeLayout() {
        let height = TableOfContentsPaneViewController.resolvedPaneHeight(
            preferredHeight: 420,
            availableHeight: 0
        )

        XCTAssertEqual(height, 420)
    }

    private func makeItems(count: Int) -> [TableOfContentsItem] {
        (0..<count).map { index in
            TableOfContentsItem(level: 2, title: "Heading \(index + 1)", id: "heading-\(index + 1)")
        }
    }
}
