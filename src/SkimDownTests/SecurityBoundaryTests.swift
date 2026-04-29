import XCTest
@testable import SkimDown

final class SecurityBoundaryTests: XCTestCase {
    func testPathContainmentUsesPathBoundaries() throws {
        let parent = try TemporaryFolder()
        let folder = parent.url.appendingPathComponent("folder")
        let sibling = parent.url.appendingPathComponent("folder-sibling")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)

        let inside = folder.appendingPathComponent("doc.md")
        let outside = sibling.appendingPathComponent("doc.md")
        FileManager.default.createFile(atPath: inside.path, contents: Data())
        FileManager.default.createFile(atPath: outside.path, contents: Data())

        XCTAssertTrue(PathSecurity.isFileURL(inside, containedIn: folder))
        XCTAssertFalse(PathSecurity.isFileURL(outside, containedIn: folder))
    }
}

