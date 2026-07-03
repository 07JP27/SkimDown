import AppKit
import XCTest
@testable import SkimDown

@MainActor
final class TableOfContentsPaneViewControllerTests: XCTestCase {
    func testPreferredPaneHeightExpandsForLongTableOfContents() {
        let controller = TableOfContentsPaneViewController()
        controller.loadViewIfNeeded()

        controller.update(items: makeItems(count: 20))

        XCTAssertGreaterThan(controller.preferredPaneHeight, 360)
    }

    func testPreferredPaneHeightKeepsShortTableOfContentsCompact() {
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

    func testResolvedPaneHeightClampsNegativeAvailableHeight() {
        let height = TableOfContentsPaneViewController.resolvedPaneHeight(
            preferredHeight: 420,
            availableHeight: -12
        )

        XCTAssertEqual(height, 0)
    }

    func testNativeBackgroundColorParsesShortHex() {
        assertColor(
            TableOfContentsPaneViewController.nativeBackgroundColor(from: "#abc"),
            red: 170,
            green: 187,
            blue: 204,
            alpha: 255
        )
    }

    func testNativeBackgroundColorParsesShortHexWithAlpha() {
        assertColor(
            TableOfContentsPaneViewController.nativeBackgroundColor(from: "#abcd"),
            red: 170,
            green: 187,
            blue: 204,
            alpha: 221
        )
    }

    func testNativeBackgroundColorParsesLongHexWithAlpha() {
        assertColor(
            TableOfContentsPaneViewController.nativeBackgroundColor(from: "#12345678"),
            red: 18,
            green: 52,
            blue: 86,
            alpha: 120
        )
    }

    func testNativeBackgroundColorRejectsUnsupportedValues() {
        XCTAssertNil(TableOfContentsPaneViewController.nativeBackgroundColor(from: "rgb(10, 20, 30)"))
        XCTAssertNil(TableOfContentsPaneViewController.nativeBackgroundColor(from: "transparent"))
        XCTAssertNil(TableOfContentsPaneViewController.nativeBackgroundColor(from: "#12"))
    }

    private func makeItems(count: Int) -> [TableOfContentsItem] {
        (0..<count).map { index in
            TableOfContentsItem(level: 2, title: "Heading \(index + 1)", id: "heading-\(index + 1)")
        }
    }

    private func assertColor(
        _ color: NSColor?,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let color else {
            XCTFail("Expected a parseable color", file: file, line: line)
            return
        }
        XCTAssertEqual(color.redComponent, red / 255, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(color.greenComponent, green / 255, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(color.blueComponent, blue / 255, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(color.alphaComponent, alpha / 255, accuracy: 0.001, file: file, line: line)
    }
}
