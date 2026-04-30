import AppKit
import XCTest
@testable import SkimDown

final class PasteboardFolderURLTests: XCTestCase {
    func testReturnsFolderURL() throws {
        let folder = try TemporaryFolder()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.writeObjects([folder.url as NSURL])

        XCTAssertEqual(pasteboard.skimdownFolderURL, folder.url)
    }

    func testIgnoresFileURL() throws {
        let folder = try TemporaryFolder()
        try folder.write("file", to: "file.md")
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.writeObjects([folder.url.appendingPathComponent("file.md") as NSURL])

        XCTAssertNil(pasteboard.skimdownFolderURL)
    }

    func testReturnsNilForEmptyPasteboard() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()

        XCTAssertNil(pasteboard.skimdownFolderURL)
    }
}