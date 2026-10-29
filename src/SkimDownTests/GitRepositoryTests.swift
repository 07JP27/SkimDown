import XCTest
@testable import SkimDown

final class GitRepositoryTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(GitCommandRunner().isAvailable, "Developer tools with git are not installed")
    }

    func testOpenRequiresWorkingTreeRoot() throws {
        let folder = try TemporaryFolder()
        try folder.write("# Doc", to: "docs/doc.md")
        try git(["init", "-q"], in: folder.url)

        let repository = try XCTUnwrap(GitRepository.open(folderURL: folder.url))
        XCTAssertEqual(repository.workTreeURL, folder.url.skimdownCanonicalFileURL)
        XCTAssertEqual(repository.objectFormat, .sha1)
        XCTAssertNil(GitRepository.open(folderURL: folder.url.appendingPathComponent("docs")))

        let plainFolder = try TemporaryFolder()
        XCTAssertNil(GitRepository.open(folderURL: plainFolder.url))
    }

    func testOpenAcceptsLinkedWorktree() throws {
        let folder = try TemporaryFolder()
        let repositoryURL = folder.url.appendingPathComponent("main")
        try folder.write("# Doc\n", to: "main/doc.md")
        try git(["init", "-q"], in: repositoryURL)
        try git(["add", "doc.md"], in: repositoryURL)
        try git(["commit", "-q", "-m", "Initial"], in: repositoryURL)
        let worktreeURL = folder.url.appendingPathComponent("linked")
        try git(["worktree", "add", "-q", "-b", "linked", worktreeURL.path], in: repositoryURL)

        let repository = try XCTUnwrap(GitRepository.open(folderURL: worktreeURL))
        XCTAssertEqual(repository.workTreeURL, worktreeURL.skimdownCanonicalFileURL)
        XCTAssertNotEqual(repository.gitDirectoryURL, repository.commonDirectoryURL)
        XCTAssertEqual(repository.commonDirectoryURL, repositoryURL.appendingPathComponent(".git").skimdownCanonicalFileURL)

        let snapshot = repository.loadSnapshot()
        XCTAssertEqual(repository.statuses(forRelativePaths: ["doc.md"], snapshot: snapshot), [:])
    }

    func testUnbornHeadReportsUntrackedAndAddedFiles() throws {
        let folder = try TemporaryFolder()
        try folder.write("new\n", to: "new.md")
        try folder.write("staged\n", to: "staged.md")
        try git(["init", "-q"], in: folder.url)
        try git(["add", "staged.md"], in: folder.url)

        let repository = try XCTUnwrap(GitRepository.open(folderURL: folder.url))
        let snapshot = repository.loadSnapshot()

        XCTAssertTrue(snapshot.headBlobIDs.isEmpty)
        XCTAssertEqual(
            repository.statuses(forRelativePaths: ["new.md", "staged.md"], snapshot: snapshot),
            ["new.md": .untracked, "staged.md": .added]
        )
        XCTAssertEqual(repository.baseText(forRelativePath: "new.md", snapshot: snapshot), "")
        XCTAssertEqual(repository.baseText(forRelativePath: "staged.md", snapshot: snapshot), "")
    }

    func testStatusesAndBaseTextCompareWithHead() throws {
        let folder = try TemporaryFolder()
        try folder.write("ignored.md\n", to: ".gitignore")
        try folder.write("same\n", to: "same.md")
        try folder.write("before\n", to: "docs/changed.md")
        try folder.write("a\nb\n", to: "crlf.md")
        try git(["init", "-q"], in: folder.url)
        try git(["add", "."], in: folder.url)
        try git(["commit", "-q", "-m", "Initial"], in: folder.url)

        try folder.write("after\n", to: "docs/changed.md")
        try folder.write("a\r\nb\r\n", to: "crlf.md")
        try folder.write("untracked\n", to: "untracked.md")
        try folder.write("staged\n", to: "staged.md")
        try folder.write("ignored\n", to: "ignored.md")
        try git(["add", "staged.md"], in: folder.url)

        let repository = try XCTUnwrap(GitRepository.open(folderURL: folder.url))
        let snapshot = repository.loadSnapshot()
        let paths = ["same.md", "docs/changed.md", "crlf.md", "untracked.md", "staged.md", "ignored.md"]

        XCTAssertEqual(repository.statuses(forRelativePaths: paths, snapshot: snapshot), [
            "docs/changed.md": .modified,
            "untracked.md": .untracked,
            "staged.md": .added
        ])
        XCTAssertEqual(repository.baseText(forRelativePath: "docs/changed.md", snapshot: snapshot), "before\n")
        XCTAssertEqual(repository.baseText(forRelativePath: "same.md", snapshot: snapshot), "same\n")
        XCTAssertNil(repository.baseText(forRelativePath: "ignored.md", snapshot: snapshot))

        let blobID = try XCTUnwrap(snapshot.headBlobIDs["same.md"])
        XCTAssertEqual(repository.blobData(blobID: blobID), Data("same\n".utf8))
        XCTAssertEqual(GitRepository.blobID(for: Data("same\n".utf8), objectFormat: .sha1), blobID)
        XCTAssertNil(repository.blobData(blobID: "--output=/tmp/x"))
    }

    func testReferenceWatcherAcceptsOnlyReferenceFiles() {
        let gitDirectory = URL(fileURLWithPath: "/tmp/repo/.git/worktrees/linked")
        let commonDirectory = URL(fileURLWithPath: "/tmp/repo/.git")
        let roots = [gitDirectory, commonDirectory]

        for path in ["worktrees/linked/HEAD", "worktrees/linked/index", "refs/heads/main", "packed-refs", "HEAD"] {
            XCTAssertTrue(GitReferenceWatcher.isReferenceEvent(url: commonDirectory.appendingPathComponent(path), rootURLs: roots), path)
        }
        for path in ["index.lock", "refs/heads/main.lock", "objects/ab/cdef", "logs/HEAD", "config"] {
            XCTAssertFalse(GitReferenceWatcher.isReferenceEvent(url: commonDirectory.appendingPathComponent(path), rootURLs: roots), path)
        }
        XCTAssertFalse(GitReferenceWatcher.isReferenceEvent(url: URL(fileURLWithPath: "/tmp/repo/HEAD"), rootURLs: roots))
    }

    @discardableResult
    private func git(_ arguments: [String], in directoryURL: URL) throws -> String {
        let process = Process()
        process.executableURL = GitCommandRunner.gitURL
        process.arguments = [
            "-c", "user.name=SkimDown Tests",
            "-c", "user.email=tests@example.invalid",
            "-c", "commit.gpgsign=false",
            "-c", "init.defaultBranch=main"
        ] + arguments
        process.currentDirectoryURL = directoryURL
        process.environment = GitCommandRunner.environment()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw GitTestError.commandFailed(arguments.joined(separator: " "), output)
        }
        return output
    }
}

private enum GitTestError: Error {
    case commandFailed(String, String)
}
