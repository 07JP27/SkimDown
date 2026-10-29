import XCTest
@testable import SkimDown

final class LineDiffTests: XCTestCase {
    func testInsertionCreatesAddOnlyHunk() {
        XCTAssertEqual(
            LineDiff.hunks(old: "a\nb\n", new: "a\nx\nb\n"),
            [LineDiffHunk(newStart: 1, newCount: 1, oldStart: 1, oldCount: 0, oldLines: [])]
        )
    }

    func testDeletionKeepsRemovedLines() {
        XCTAssertEqual(
            LineDiff.hunks(old: "a\nb\nc\n", new: "a\nc\n"),
            [LineDiffHunk(newStart: 1, newCount: 0, oldStart: 1, oldCount: 1, oldLines: ["b"])]
        )
    }

    func testReplacementGroupsRemovalAndInsertion() {
        XCTAssertEqual(
            LineDiff.hunks(old: "a\nb\nc\nd\n", new: "a\nB\nc\nD\n"),
            [
                LineDiffHunk(newStart: 1, newCount: 1, oldStart: 1, oldCount: 1, oldLines: ["b"]),
                LineDiffHunk(newStart: 3, newCount: 1, oldStart: 3, oldCount: 1, oldLines: ["d"])
            ]
        )
    }

    func testLineEndingsAndByteOrderMarkAreNormalized() {
        XCTAssertEqual(LineDiff.hunks(old: "a\r\nb\r\n", new: "a\nb\n"), [])
        XCTAssertEqual(LineDiff.hunks(old: "\u{FEFF}a\nb", new: "a\nb\n"), [])
        XCTAssertEqual(LineDiff.lines(in: "a\r\nb\rc\n"), ["a", "b", "c"])
    }

    func testEmptyBaseMarksWholeDocumentAsAdded() {
        XCTAssertEqual(
            LineDiff.hunks(old: "", new: "# Title\n\nBody\n"),
            [LineDiffHunk(newStart: 0, newCount: 3, oldStart: 0, oldCount: 0, oldLines: [])]
        )
        XCTAssertEqual(LineDiff.hunks(old: "", new: ""), [])
    }
}
