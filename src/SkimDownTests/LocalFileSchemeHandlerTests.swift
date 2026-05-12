import XCTest
import WebKit
@testable import SkimDown

// MARK: - Mock WKURLSchemeTask

private final class MockURLSchemeTask: NSObject, WKURLSchemeTask, @unchecked Sendable {
    let request: URLRequest
    private(set) var receivedResponse: URLResponse?
    private(set) var receivedData: Data?
    private(set) var didFinishCalled = false
    private(set) var failedError: (any Error)?

    init(url: URL) {
        self.request = URLRequest(url: url)
    }

    func didReceive(_ response: URLResponse) {
        receivedResponse = response
    }

    func didReceive(_ data: Data) {
        receivedData = (receivedData ?? Data()) + data
    }

    func didFinish() {
        didFinishCalled = true
    }

    func didFailWithError(_ error: any Error) {
        failedError = error
    }
}

// MARK: - Tests

final class LocalFileSchemeHandlerTests: XCTestCase {
    func testRootFolderURLGetterSetter() {
        let handler = LocalFileSchemeHandler()
        XCTAssertNil(handler.rootFolderURL)

        let folder = URL(fileURLWithPath: "/tmp/test-folder")
        handler.rootFolderURL = folder
        XCTAssertEqual(handler.rootFolderURL, folder)
    }

    func testSchemeConstant() {
        XCTAssertEqual(LocalFileSchemeHandler.scheme, "skimdown-local")
    }

    func testServesFileInsideRootFolder() throws {
        let tmp = try TemporaryFolder()
        try tmp.write("hello", to: "image.png")

        let handler = LocalFileSchemeHandler()
        handler.rootFolderURL = tmp.url

        let fileURL = tmp.url.appendingPathComponent("image.png")
        let requestURL = URL(string: "skimdown-local://\(fileURL.path)")!
        let task = MockURLSchemeTask(url: requestURL)

        handler.webView(WKWebView(), start: task)

        XCTAssertTrue(task.didFinishCalled)
        XCTAssertNil(task.failedError)
        XCTAssertEqual(task.receivedData, "hello".data(using: .utf8))
        XCTAssertNotNil(task.receivedResponse)
        XCTAssertEqual(task.receivedResponse?.mimeType, "image/png")
    }

    func testRejectsFileOutsideRootFolder() throws {
        let tmp = try TemporaryFolder()
        let outsideFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkimDownTests-outside-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outsideFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outsideFolder) }

        let outsideFile = outsideFolder.appendingPathComponent("secret.png")
        FileManager.default.createFile(atPath: outsideFile.path, contents: Data("secret".utf8))

        let handler = LocalFileSchemeHandler()
        handler.rootFolderURL = tmp.url

        let requestURL = URL(string: "skimdown-local://\(outsideFile.path)")!
        let task = MockURLSchemeTask(url: requestURL)

        handler.webView(WKWebView(), start: task)

        XCTAssertFalse(task.didFinishCalled)
        XCTAssertNotNil(task.failedError)
    }

    func testRejectsWhenNoRootFolderSet() throws {
        let tmp = try TemporaryFolder()
        try tmp.write("data", to: "file.png")

        let handler = LocalFileSchemeHandler()

        let fileURL = tmp.url.appendingPathComponent("file.png")
        let requestURL = URL(string: "skimdown-local://\(fileURL.path)")!
        let task = MockURLSchemeTask(url: requestURL)

        handler.webView(WKWebView(), start: task)

        XCTAssertFalse(task.didFinishCalled)
        XCTAssertNotNil(task.failedError)
    }

    func testReturnsErrorForMissingFile() throws {
        let tmp = try TemporaryFolder()

        let handler = LocalFileSchemeHandler()
        handler.rootFolderURL = tmp.url

        let missingURL = tmp.url.appendingPathComponent("nonexistent.png")
        let requestURL = URL(string: "skimdown-local://\(missingURL.path)")!
        let task = MockURLSchemeTask(url: requestURL)

        handler.webView(WKWebView(), start: task)

        XCTAssertFalse(task.didFinishCalled)
        XCTAssertNotNil(task.failedError)
    }
}
