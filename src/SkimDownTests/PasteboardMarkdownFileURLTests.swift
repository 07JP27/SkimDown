import AppKit
import XCTest
@testable import SkimDown

final class PasteboardMarkdownFileURLTests: XCTestCase {
    func testReturnsMarkdownFileURL() throws {
        let folder = try TemporaryFolder()
        try folder.write("# Hello", to: "test.md")
        let fileURL = folder.url.appendingPathComponent("test.md")
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.writeObjects([fileURL as NSURL])

        XCTAssertEqual(pasteboard.skimdownMarkdownFileURL, fileURL)
    }

    func testReturnsMarkdownExtensionFile() throws {
        let folder = try TemporaryFolder()
        try folder.write("# Hello", to: "test.markdown")
        let fileURL = folder.url.appendingPathComponent("test.markdown")
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.writeObjects([fileURL as NSURL])

        XCTAssertEqual(pasteboard.skimdownMarkdownFileURL, fileURL)
    }

    func testIgnoresNonMarkdownFile() throws {
        let folder = try TemporaryFolder()
        try folder.write("hello", to: "test.txt")
        let fileURL = folder.url.appendingPathComponent("test.txt")
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.writeObjects([fileURL as NSURL])

        XCTAssertNil(pasteboard.skimdownMarkdownFileURL)
    }

    func testIgnoresFolderURL() throws {
        let folder = try TemporaryFolder()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.writeObjects([folder.url as NSURL])

        XCTAssertNil(pasteboard.skimdownMarkdownFileURL)
    }

    func testReturnsNilForEmptyPasteboard() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()

        XCTAssertNil(pasteboard.skimdownMarkdownFileURL)
    }
}
