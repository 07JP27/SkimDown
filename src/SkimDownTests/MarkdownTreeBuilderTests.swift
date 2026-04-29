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

    func testParentReferencesAreSetCorrectly() throws {
        let folder = try TemporaryFolder()
        try folder.write("root", to: "root.md")
        try folder.write("nested", to: "docs/deep/nested.md")

        let files = try MarkdownScanner().scan(folderURL: folder.url)
        let tree = MarkdownTreeBuilder().buildTree(folderURL: folder.url, markdownFiles: files)

        // root.md at top level has no parent (parent is the virtual root, not included in tree)
        let rootFile = tree.first(where: { $0.name == "root.md" })
        XCTAssertNotNil(rootFile)
        XCTAssertNil(rootFile?.parent)

        // docs/deep/nested.md should have parent chain: deep -> docs
        let docsDir = tree.first(where: { $0.name == "docs" })
        XCTAssertNotNil(docsDir)
        let deepDir = docsDir?.children.first(where: { $0.name == "deep" })
        XCTAssertNotNil(deepDir)
        let nestedFile = deepDir?.children.first(where: { $0.name == "nested.md" })
        XCTAssertNotNil(nestedFile)

        XCTAssertTrue(nestedFile?.parent === deepDir)
        XCTAssertTrue(deepDir?.parent === docsDir)
    }
}

