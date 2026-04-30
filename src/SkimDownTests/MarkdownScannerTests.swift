import XCTest
@testable import SkimDown

final class MarkdownScannerTests: XCTestCase {
    func testScansMarkdownExtensionsRecursively() throws {
        let folder = try TemporaryFolder()
        try folder.write("root", to: "README.md")
        try folder.write("nested", to: "Docs/Guide.markdown")
        try folder.write("image", to: "Docs/image.png")

        let files = try MarkdownScanner().scan(folderURL: folder.url)
        let relativePaths = Set(files.compactMap { PathSecurity.relativePath(for: $0, in: folder.url) })

        XCTAssertEqual(relativePaths, ["README.md", "Docs/Guide.markdown"])
    }

    func testExcludesIgnoredDirectoriesAndHiddenFiles() throws {
        let folder = try TemporaryFolder()
        try folder.write("visible", to: "visible.md")
        try folder.write("git", to: ".git/config.md")
        try folder.write("node", to: "node_modules/package.md")
        try folder.write("build", to: ".build/generated.md")
        try folder.write("derived", to: "DerivedData/output.md")
        try folder.write("hidden", to: ".hidden.md")
        try folder.write("hidden folder", to: ".secret/readme.md")

        let files = try MarkdownScanner().scan(folderURL: folder.url)
        let relativePaths = Set(files.compactMap { PathSecurity.relativePath(for: $0, in: folder.url) })

        XCTAssertEqual(relativePaths, ["visible.md"])
    }

    func testSkipsSymbolicLinks() throws {
        let folder = try TemporaryFolder()
        let outside = try TemporaryFolder()
        try folder.write("visible", to: "visible.md")
        try outside.write("outside", to: "outside.md")
        try outside.write("nested", to: "nested/secret.md")

        let fileSymlink = folder.url.appendingPathComponent("linked.md")
        let directorySymlink = folder.url.appendingPathComponent("linked-directory")
        try FileManager.default.createSymbolicLink(at: fileSymlink, withDestinationURL: outside.url.appendingPathComponent("outside.md"))
        try FileManager.default.createSymbolicLink(at: directorySymlink, withDestinationURL: outside.url)

        let files = try MarkdownScanner().scan(folderURL: folder.url)
        let relativePaths = Set(files.compactMap { PathSecurity.relativePath(for: $0, in: folder.url) })

        XCTAssertEqual(relativePaths, ["visible.md"])
    }
}

