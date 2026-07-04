import CoreGraphics
import XCTest
@testable import SkimDown

final class TableOfContentsPlacementTests: XCTestCase {
    func testLeadingOffsetPlacesPaneNextToContentWhenSpaceAllows() {
        let leading = TableOfContentsPlacement.leadingOffset(
            contentRight: 1_500,
            containerWidth: 2_200,
            paneWidth: 260,
            trailingInset: 16,
            gutter: 24
        )

        XCTAssertEqual(leading, 1_524)
    }

    func testLeadingOffsetClampsToTrailingEdgeWhenContentIsTooWide() {
        let leading = TableOfContentsPlacement.leadingOffset(
            contentRight: 800,
            containerWidth: 1_000,
            paneWidth: 260,
            trailingInset: 16,
            gutter: 24
        )

        XCTAssertEqual(leading, 724)
    }

    func testLeadingOffsetFallsBackToTrailingEdgeWithoutContentMetrics() {
        let leading = TableOfContentsPlacement.leadingOffset(
            contentRight: nil,
            containerWidth: 1_400,
            paneWidth: 260,
            trailingInset: 16,
            gutter: 24
        )

        XCTAssertEqual(leading, 1_124)
    }

    func testLeadingOffsetDoesNotReturnNegativeValueForNarrowContainers() {
        let leading = TableOfContentsPlacement.leadingOffset(
            contentRight: 80,
            containerWidth: 180,
            paneWidth: 260,
            trailingInset: 16,
            gutter: 24
        )

        XCTAssertEqual(leading, 0)
    }

    func testTableOfContentsVisibilityShowsLoadedPaneWhenEnabled() {
        let isVisible = TableOfContentsVisibility.shouldShowPane(
            isSettingEnabled: true,
            isWebViewVisible: true,
            hasSelectedFile: true,
            hasLoadedTableOfContents: true,
            isMermaidModalPresented: false
        )

        XCTAssertTrue(isVisible)
    }

    func testTableOfContentsVisibilityHidesPaneWhileMermaidModalIsPresented() {
        let isVisible = TableOfContentsVisibility.shouldShowPane(
            isSettingEnabled: true,
            isWebViewVisible: true,
            hasSelectedFile: true,
            hasLoadedTableOfContents: true,
            isMermaidModalPresented: true
        )

        XCTAssertFalse(isVisible)
    }

    func testTableOfContentsVisibilityRequiresLoadedItems() {
        let isVisible = TableOfContentsVisibility.shouldShowPane(
            isSettingEnabled: true,
            isWebViewVisible: true,
            hasSelectedFile: true,
            hasLoadedTableOfContents: false,
            isMermaidModalPresented: false
        )

        XCTAssertFalse(isVisible)
    }

    func testTableOfContentsReserveWidthKeepsLoadedContentReserved() {
        let shouldReserveWidth = TableOfContentsVisibility.shouldReserveTrailingWidth(
            isSettingEnabled: true,
            isWebViewVisible: true,
            hasSelectedFile: true,
            hasLoadedTableOfContents: true,
            reserveWidthWhileLoading: false
        )

        XCTAssertTrue(shouldReserveWidth)
    }

    func testTableOfContentsReserveWidthCanReserveBeforeItemsLoad() {
        let shouldReserveWidth = TableOfContentsVisibility.shouldReserveTrailingWidth(
            isSettingEnabled: true,
            isWebViewVisible: true,
            hasSelectedFile: true,
            hasLoadedTableOfContents: false,
            reserveWidthWhileLoading: true
        )

        XCTAssertTrue(shouldReserveWidth)
    }

    func testTableOfContentsReserveWidthRequiresPreviewContext() {
        let shouldReserveWidth = TableOfContentsVisibility.shouldReserveTrailingWidth(
            isSettingEnabled: true,
            isWebViewVisible: false,
            hasSelectedFile: true,
            hasLoadedTableOfContents: true,
            reserveWidthWhileLoading: true
        )

        XCTAssertFalse(shouldReserveWidth)
    }

    func testEstimatedContentRightFillsAvailableBodyWidthBeforeMaxWidth() {
        let contentRight = PreviewContentLayout.estimatedContentRight(
            containerWidth: 1_400,
            fontSize: 16,
            reservedTrailingWidth: 300
        )

        XCTAssertEqual(contentRight, 1_100, accuracy: 0.001)
    }

    func testEstimatedContentRightCentersBoundedContentOnUltrawideWindows() {
        let contentRight = PreviewContentLayout.estimatedContentRight(
            containerWidth: 2_200,
            fontSize: 16,
            reservedTrailingWidth: 300
        )

        XCTAssertEqual(contentRight, 1_746, accuracy: 0.001)
    }

    func testEstimatedContentRightScalesRemWithPreviewFontSize() {
        let contentRight = PreviewContentLayout.estimatedContentRight(
            containerWidth: 3_000,
            fontSize: 28,
            reservedTrailingWidth: 300
        )

        XCTAssertEqual(contentRight, 2_698, accuracy: 0.001)
    }
}
