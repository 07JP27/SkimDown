import XCTest
@testable import SkimDown

final class FileWatcherTests: XCTestCase {
    func testWatchedDirectoriesRespectLimit() throws {
        let folder = try TemporaryFolder()
        for index in 0..<12 {
            try FileManager.default.createDirectory(
                at: folder.url.appendingPathComponent("Dir\(index)", isDirectory: true),
                withIntermediateDirectories: true
            )
        }

        let directories = FileWatcher.watchedDirectories(folderURL: folder.url, limit: 5)

        XCTAssertEqual(directories.count, 5)
        XCTAssertEqual(directories.first, folder.url)
    }

    func testWatchedDirectoriesSkipExcludedDirectories() throws {
        let folder = try TemporaryFolder()
        try FileManager.default.createDirectory(
            at: folder.url.appendingPathComponent("Docs", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: folder.url.appendingPathComponent("node_modules/package", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: folder.url.appendingPathComponent(".git/hooks", isDirectory: true),
            withIntermediateDirectories: true
        )

        let directories = FileWatcher.watchedDirectories(folderURL: folder.url)
        let relativePaths = Set(directories.compactMap { PathSecurity.relativePath(for: $0, in: folder.url) })

        XCTAssertEqual(relativePaths, ["", "Docs"])
    }
}