import XCTest
@testable import SkimDown

final class LocalFileSchemeHandlerTests: XCTestCase {
    func testRootFolderURLIsThreadSafe() {
        let handler = LocalFileSchemeHandler()
        XCTAssertNil(handler.rootFolderURL)

        let folder = URL(fileURLWithPath: "/tmp/test-folder")
        handler.rootFolderURL = folder
        XCTAssertEqual(handler.rootFolderURL, folder)
    }

    func testSchemeConstant() {
        XCTAssertEqual(LocalFileSchemeHandler.scheme, "skimdown-local")
    }
}
