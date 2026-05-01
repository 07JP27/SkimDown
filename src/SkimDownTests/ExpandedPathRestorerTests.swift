import XCTest
@testable import SkimDown

final class ExpandedPathRestorerTests: XCTestCase {
    private func makeFile(_ name: String, relativePath: String) -> MarkdownTreeItem {
        MarkdownTreeItem(name: name, url: URL(fileURLWithPath: "/tmp/\(relativePath)"), relativePath: relativePath, isDirectory: false)
    }

    private func makeDir(_ name: String, relativePath: String, children: [MarkdownTreeItem] = []) -> MarkdownTreeItem {
        let dir = MarkdownTreeItem(name: name, url: URL(fileURLWithPath: "/tmp/\(relativePath)"), relativePath: relativePath, isDirectory: true, children: children)
        for child in children {
            child.parent = dir
        }
        return dir
    }

    func testReturnsEmptyForEmptyDesired() {
        let tree = [makeDir("a", relativePath: "a", children: [makeFile("x.md", relativePath: "a/x.md")])]
        XCTAssertTrue(ExpandedPathRestorer.itemsToExpand(in: tree, desired: []).isEmpty)
    }

    func testReturnsEmptyForEmptyTree() {
        XCTAssertTrue(ExpandedPathRestorer.itemsToExpand(in: [], desired: ["a", "b"]).isEmpty)
    }

    func testIncludesOnlyDirectoryItemsMatchingDesired() {
        let file = makeFile("readme.md", relativePath: "readme.md")
        let dir = makeDir("docs", relativePath: "docs", children: [makeFile("guide.md", relativePath: "docs/guide.md")])
        let tree = [dir, file]

        let result = ExpandedPathRestorer.itemsToExpand(in: tree, desired: ["docs", "readme.md"])

        XCTAssertEqual(result.map(\.relativePath), ["docs"])
    }

    func testReturnsParentsBeforeChildrenForNestedDirectories() {
        let nestedFile = makeFile("nested.md", relativePath: "a/b/c/nested.md")
        let cDir = makeDir("c", relativePath: "a/b/c", children: [nestedFile])
        let bDir = makeDir("b", relativePath: "a/b", children: [cDir])
        let aDir = makeDir("a", relativePath: "a", children: [bDir])
        let tree = [aDir]

        let result = ExpandedPathRestorer.itemsToExpand(in: tree, desired: ["a", "a/b", "a/b/c"])

        XCTAssertEqual(result.map(\.relativePath), ["a", "a/b", "a/b/c"])
    }

    func testIgnoresDesiredPathsNotInTree() {
        let dir = makeDir("docs", relativePath: "docs")
        let result = ExpandedPathRestorer.itemsToExpand(in: [dir], desired: ["docs", "missing", "missing/inner"])

        XCTAssertEqual(result.map(\.relativePath), ["docs"])
    }

    func testHandlesSiblingsAndPartialMatches() {
        let alphaChildDir = makeDir("inner", relativePath: "Alpha/inner", children: [makeFile("p.md", relativePath: "Alpha/inner/p.md")])
        let alphaDir = makeDir("Alpha", relativePath: "Alpha", children: [alphaChildDir, makeFile("a.md", relativePath: "Alpha/a.md")])
        let betaDir = makeDir("Beta", relativePath: "Beta", children: [makeFile("b.md", relativePath: "Beta/b.md")])
        let tree = [alphaDir, betaDir]

        // Beta is not desired; Alpha/inner is desired but Alpha is not — only Alpha/inner should appear.
        let result = ExpandedPathRestorer.itemsToExpand(in: tree, desired: ["Alpha/inner"])

        XCTAssertEqual(result.map(\.relativePath), ["Alpha/inner"])
    }
}
