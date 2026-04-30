import XCTest
@testable import SkimDown

final class LinkResolverTests: XCTestCase {
    func testRoutesAnchorsRelativeMarkdownAndExternalLinks() throws {
        let folder = try TemporaryFolder()
        try folder.write("current", to: "docs/current.md")
        try folder.write("target", to: "docs/target.md")
        let current = folder.url.appendingPathComponent("docs/current.md").skimdownCanonicalFileURL
        let target = folder.url.appendingPathComponent("docs/target.md").skimdownCanonicalFileURL
        let files: Set<URL> = [current, target]
        let router = LinkRouter()

        XCTAssertEqual(router.route(href: "#section", currentFileURL: current, folderURL: folder.url, markdownFiles: files), .anchor("section"))
        XCTAssertEqual(router.route(href: "target.md#part", currentFileURL: current, folderURL: folder.url, markdownFiles: files), .markdownFile(target, anchor: "part"))

        if case .external(let url) = router.route(href: "https://example.com", currentFileURL: current, folderURL: folder.url, markdownFiles: files) {
            XCTAssertEqual(url.absoluteString, "https://example.com")
        } else {
            XCTFail("Expected external route")
        }
    }

    func testBlocksLocalFilesOutsideOpenedFolder() throws {
        let folder = try TemporaryFolder()
        let outside = try TemporaryFolder()
        try folder.write("current", to: "current.md")
        try outside.write("outside", to: "outside.md")
        let current = folder.url.appendingPathComponent("current.md").skimdownCanonicalFileURL
        let outsideURL = outside.url.appendingPathComponent("outside.md").skimdownCanonicalFileURL

        let route = LinkRouter().route(href: outsideURL.absoluteString, currentFileURL: current, folderURL: folder.url, markdownFiles: [current])
        XCTAssertEqual(route, .blocked)
    }
}

