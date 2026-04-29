import XCTest
@testable import SkimDown

final class MarkdownTreeBuilderTests: XCTestCase {
    func testBuildsFolderFirstCaseInsensitiveTreeAndOmitsEmptyFolders() throws {
        let folder = try TemporaryFolder()
        try folder.write("b", to: "zeta.md")
        try folder.write("a", to: "Alpha/guide.md")
        try FileManager.default.createDirectory(at: folder.url.appendingPathComponent("Empty"), withIntermediateDirectories: true)

        let files = try MarkdownScanner().scan(folderURL: folder.url)
        let tree = MarkdownTreeBuilder().buildTree(folderURL: folder.url, markdownFiles: files)

        XCTAssertEqual(tree.map(\.name), ["Alpha", "zeta.md"])
        XCTAssertTrue(tree[0].isDirectory)
        XCTAssertEqual(tree[0].children.map(\.name), ["guide.md"])
    }
}

