import XCTest
@testable import SkimDown

@MainActor
final class FileWatcherTests: XCTestCase {
    func testDebouncesEventBursts() throws {
        let folder = try TemporaryFolder()
        let eventSource = MockFileWatchEventSource()
        let watcher = FileWatcher(eventSource: eventSource)
        let expectation = expectation(description: "onChange called once")
        expectation.expectedFulfillmentCount = 1

        watcher.onChange = {
            expectation.fulfill()
        }

        try watcher.start(folderURL: folder.url)
        eventSource.emit([folder.url.appendingPathComponent("one.md")])
        eventSource.emit([folder.url.appendingPathComponent("two.md")])

        wait(for: [expectation], timeout: 1.0)
        watcher.stop()
    }

    func testStopCancelsPendingDebounce() throws {
        let folder = try TemporaryFolder()
        let eventSource = MockFileWatchEventSource()
        let watcher = FileWatcher(eventSource: eventSource)
        let expectation = expectation(description: "onChange is not called")
        expectation.isInverted = true

        watcher.onChange = {
            expectation.fulfill()
        }

        try watcher.start(folderURL: folder.url)
        eventSource.emit([folder.url.appendingPathComponent("file.md")])
        watcher.stop()

        wait(for: [expectation], timeout: 0.5)
    }

    func testIgnoresExcludedEventPaths() throws {
        let folder = try TemporaryFolder()
        let eventSource = MockFileWatchEventSource()
        let watcher = FileWatcher(eventSource: eventSource)
        let expectation = expectation(description: "onChange is not called for excluded paths")
        expectation.isInverted = true

        watcher.onChange = {
            expectation.fulfill()
        }

        try watcher.start(folderURL: folder.url)
        eventSource.emit([
            folder.url.appendingPathComponent(".git/config"),
            folder.url.appendingPathComponent("node_modules/package/index.js"),
            folder.url.appendingPathComponent(".hidden/file.md")
        ])

        wait(for: [expectation], timeout: 0.5)
        watcher.stop()
    }

    func testAllowsNonExcludedEventPaths() throws {
        let folder = try TemporaryFolder()
        let eventSource = MockFileWatchEventSource()
        let watcher = FileWatcher(eventSource: eventSource)
        let expectation = expectation(description: "onChange is called")

        watcher.onChange = {
            expectation.fulfill()
        }

        try watcher.start(folderURL: folder.url)
        eventSource.emit([folder.url.appendingPathComponent("Docs/guide.md")])

        wait(for: [expectation], timeout: 1.0)
        watcher.stop()
    }
}

private final class MockFileWatchEventSource: FileWatchEventSource, @unchecked Sendable {
    private var onEvent: (([URL]) -> Void)?

    func start(folderURL: URL, onEvent: @escaping ([URL]) -> Void) throws {
        self.onEvent = onEvent
    }

    func stop() {
        onEvent = nil
    }

    func emit(_ urls: [URL]) {
        onEvent?(urls)
    }
}