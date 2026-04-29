import XCTest
@testable import SkimDown

final class InitialSelectionTests: XCTestCase {
    func testPrefersLastFileThenReadmeThenFirstTreeFile() throws {
        let folder = try TemporaryFolder()
        try folder.write("readme", to: "README.md")
        try folder.write("first", to: "A/first.md")
        try folder.write("last", to: "B/last.md")

        let files = try MarkdownScanner().scan(folderURL: folder.url)
        let tree = MarkdownTreeBuilder().buildTree(folderURL: folder.url, markdownFiles: files)
        let resolver = InitialSelectionResolver()

        let last = resolver.resolve(folderURL: folder.url, markdownFiles: files, treeItems: tree, lastRelativePath: "B/last.md")
        XCTAssertEqual(PathSecurity.relativePath(for: try XCTUnwrap(last), in: folder.url), "B/last.md")

        let readme = resolver.resolve(folderURL: folder.url, markdownFiles: files, treeItems: tree, lastRelativePath: "missing.md")
        XCTAssertEqual(PathSecurity.relativePath(for: try XCTUnwrap(readme), in: folder.url), "README.md")
    }

    func testFallsBackToFirstTreeFileWhenNoReadme() throws {
        let folder = try TemporaryFolder()
        try folder.write("b", to: "b.md")
        try folder.write("a", to: "Folder/a.md")

        let files = try MarkdownScanner().scan(folderURL: folder.url)
        let tree = MarkdownTreeBuilder().buildTree(folderURL: folder.url, markdownFiles: files)
        let selected = InitialSelectionResolver().resolve(folderURL: folder.url, markdownFiles: files, treeItems: tree, lastRelativePath: nil)

        XCTAssertEqual(PathSecurity.relativePath(for: try XCTUnwrap(selected), in: folder.url), "Folder/a.md")
    }
}

