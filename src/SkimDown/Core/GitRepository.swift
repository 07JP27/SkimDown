import CryptoKit
import Foundation

/// `HEAD` tree and index paths, keyed by NFC-normalized repository-relative paths.
struct GitHeadSnapshot: Sendable {
    let headBlobIDs: [String: String]
    let indexPaths: Set<String>
}

/// Read-only access to a repository whose working-tree root is the opened folder.
///
/// Only plumbing commands that never run repository-configured programs are used
/// (`rev-parse`, `ls-tree`, `ls-files --cached`, `cat-file blob`, `check-ignore`).
/// `git status` / `git diff` are intentionally avoided because they can invoke
/// fsmonitor hooks, clean/process filters, or external diff tools. Calls block,
/// so callers must stay off the main thread.
final class GitRepository: @unchecked Sendable {
    enum ObjectFormat: String, Sendable {
        case sha1
        case sha256
    }

    let workTreeURL: URL
    let gitDirectoryURL: URL
    let commonDirectoryURL: URL
    let objectFormat: ObjectFormat
    private let runner: GitCommandRunner
    private let blobCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    private init(workTreeURL: URL, gitDirectoryURL: URL, commonDirectoryURL: URL, objectFormat: ObjectFormat, runner: GitCommandRunner) {
        self.workTreeURL = workTreeURL
        self.gitDirectoryURL = gitDirectoryURL
        self.commonDirectoryURL = commonDirectoryURL
        self.objectFormat = objectFormat
        self.runner = runner
    }

    /// Cheap pre-check that avoids launching git for folders that cannot be a working-tree root.
    /// `.git` may be a directory or a file (linked worktrees and submodules).
    static func hasGitEntry(in folderURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(".git").path)
    }

    /// Returns a repository only when `folderURL` itself is the working-tree root.
    static func open(folderURL: URL, runner: GitCommandRunner = GitCommandRunner()) -> GitRepository? {
        let folderURL = folderURL.skimdownCanonicalFileURL
        guard hasGitEntry(in: folderURL),
              runner.isAvailable,
              let output = runner.run(
                  ["rev-parse", "--path-format=absolute", "--show-toplevel", "--git-dir", "--git-common-dir", "--show-object-format"],
                  in: folderURL
              ) else {
            return nil
        }

        let lines = String(decoding: output, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        guard lines.count >= 4,
              URL(fileURLWithPath: lines[0], isDirectory: true).skimdownCanonicalFileURL == folderURL,
              let objectFormat = ObjectFormat(rawValue: lines[3]) else {
            return nil
        }

        return GitRepository(
            workTreeURL: folderURL,
            gitDirectoryURL: URL(fileURLWithPath: lines[1], isDirectory: true).skimdownCanonicalFileURL,
            commonDirectoryURL: URL(fileURLWithPath: lines[2], isDirectory: true).skimdownCanonicalFileURL,
            objectFormat: objectFormat,
            runner: runner
        )
    }

    func loadSnapshot() -> GitHeadSnapshot {
        var headBlobIDs: [String: String] = [:]
        // An unborn HEAD (no commits yet) fails here and is treated as an empty tree.
        if let output = runner.run(["ls-tree", "-r", "-z", "HEAD"], in: workTreeURL) {
            for record in Self.nulSeparatedStrings(output) {
                guard let tab = record.firstIndex(of: "\t") else {
                    continue
                }
                let fields = record[..<tab].split(separator: " ")
                guard fields.count == 3, fields[1] == "blob" else {
                    continue
                }
                let path = String(record[record.index(after: tab)...])
                headBlobIDs[Self.pathKey(path)] = String(fields[2])
            }
        }

        let indexPaths = runner.run(["ls-files", "-z", "--cached"], in: workTreeURL)
            .map { Set(Self.nulSeparatedStrings($0).map(Self.pathKey)) } ?? []
        return GitHeadSnapshot(headBlobIDs: headBlobIDs, indexPaths: indexPaths)
    }

    /// Statuses for the given working-tree relative paths. Unchanged and ignored files are omitted.
    func statuses(forRelativePaths relativePaths: [String], snapshot: GitHeadSnapshot) -> [String: GitFileStatus] {
        var statuses: [String: GitFileStatus] = [:]
        var untrackedCandidates: [String] = []

        for relativePath in relativePaths {
            let key = Self.pathKey(relativePath)
            if let blobID = snapshot.headBlobIDs[key] {
                guard let data = try? Data(contentsOf: workTreeURL.appendingPathComponent(relativePath)) else {
                    continue
                }
                if !matchesBlob(data, blobID: blobID) {
                    statuses[relativePath] = .modified
                }
            } else if snapshot.indexPaths.contains(key) {
                statuses[relativePath] = .added
            } else {
                untrackedCandidates.append(relativePath)
            }
        }

        let ignored = ignoredPaths(among: untrackedCandidates)
        for relativePath in untrackedCandidates where !ignored.contains(Self.pathKey(relativePath)) {
            statuses[relativePath] = .untracked
        }
        return statuses
    }

    /// Text to compare the working file against: the `HEAD` version, an empty string for
    /// files that are not in `HEAD`, or nil when the file is ignored or cannot be read.
    func baseText(forRelativePath relativePath: String, snapshot: GitHeadSnapshot) -> String? {
        let key = Self.pathKey(relativePath)
        if let blobID = snapshot.headBlobIDs[key] {
            return blobData(blobID: blobID).map(Self.decodedText)
        }
        if snapshot.indexPaths.contains(key) {
            return ""
        }
        return ignoredPaths(among: [relativePath]).isEmpty ? "" : nil
    }

    func blobData(blobID: String) -> Data? {
        guard blobID.allSatisfy(\.isHexDigit) else {
            return nil
        }
        if let cached = blobCache.object(forKey: blobID as NSString) {
            return cached as Data
        }
        guard let data = runner.run(["cat-file", "blob", blobID], in: workTreeURL) else {
            return nil
        }
        blobCache.setObject(data as NSData, forKey: blobID as NSString, cost: data.count)
        return data
    }

    /// Returns NFC-normalized keys of the paths that `.gitignore` rules exclude.
    func ignoredPaths(among relativePaths: [String]) -> Set<String> {
        guard !relativePaths.isEmpty else {
            return []
        }
        var input = Data()
        for path in relativePaths {
            input.append(Data(path.utf8))
            input.append(0)
        }
        // Exit status 1 means that none of the paths are ignored.
        guard let output = runner.run(["check-ignore", "-z", "--stdin"], in: workTreeURL, input: input, acceptedExitStatuses: [0, 1]) else {
            return []
        }
        return Set(Self.nulSeparatedStrings(output).map(Self.pathKey))
    }

    func matchesBlob(_ data: Data, blobID: String) -> Bool {
        if Self.blobID(for: data, objectFormat: objectFormat) == blobID {
            return true
        }
        // Files checked out with CRLF line endings (core.autocrlf / eol attributes) are stored with LF.
        let crlf = Data("\r\n".utf8)
        guard data.range(of: crlf) != nil else {
            return false
        }
        let normalized = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n")
        return Self.blobID(for: Data(normalized.utf8), objectFormat: objectFormat) == blobID
    }

    static func blobID(for data: Data, objectFormat: ObjectFormat) -> String {
        let header = Data("blob \(data.count)\0".utf8)
        switch objectFormat {
        case .sha1:
            var hasher = Insecure.SHA1()
            hasher.update(data: header)
            hasher.update(data: data)
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        case .sha256:
            var hasher = SHA256()
            hasher.update(data: header)
            hasher.update(data: data)
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }
    }

    private static func decodedText(_ data: Data) -> String {
        let bom = Data([0xEF, 0xBB, 0xBF])
        let body = data.starts(with: bom) ? data.dropFirst(bom.count) : data[...]
        return String(decoding: body, as: UTF8.self)
    }

    private static func nulSeparatedStrings(_ data: Data) -> [String] {
        data.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
    }

    /// macOS file names may be decomposed while git stores precomposed paths.
    private static func pathKey(_ path: String) -> String {
        path.precomposedStringWithCanonicalMapping
    }
}

/// Runs `/usr/bin/git` with a minimal environment and a timeout.
struct GitCommandRunner: Sendable {
    static let gitURL = URL(fileURLWithPath: "/usr/bin/git")
    private static let xcodeSelectURL = URL(fileURLWithPath: "/usr/bin/xcode-select")

    var timeout: TimeInterval = 10

    /// `/usr/bin/git` is a shim that shows an install prompt when no developer tools are
    /// selected, so confirm that a developer directory with git exists before using it.
    var isAvailable: Bool {
        Self.isDeveloperToolsAvailable
    }

    private static let isDeveloperToolsAvailable: Bool = {
        guard let result = execute(
            executableURL: xcodeSelectURL,
            arguments: ["-p"],
            directoryURL: nil,
            environment: environment(),
            input: nil,
            timeout: 5
        ), result.status == 0 else {
            return false
        }
        let developerDirectory = String(decoding: result.output, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !developerDirectory.isEmpty
            && FileManager.default.isExecutableFile(atPath: developerDirectory + "/usr/bin/git")
    }()

    func run(_ arguments: [String], in directoryURL: URL, input: Data? = nil, acceptedExitStatuses: Set<Int32> = [0]) -> Data? {
        guard isAvailable,
              let result = Self.execute(
                  executableURL: Self.gitURL,
                  arguments: ["--no-pager", "-c", "core.fsmonitor=false"] + arguments,
                  directoryURL: directoryURL,
                  environment: Self.environment(),
                  input: input,
                  timeout: timeout
              ),
              acceptedExitStatuses.contains(result.status) else {
            return nil
        }
        return result.output
    }

    /// Builds the child environment from scratch so inherited `GIT_*` variables
    /// (for example `GIT_DIR`) cannot redirect the command.
    static func environment(from base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "LC_ALL": "C",
            "GIT_NO_LAZY_FETCH": "1",
            "GIT_OPTIONAL_LOCKS": "0",
            "GIT_TERMINAL_PROMPT": "0"
        ]
        for key in ["HOME", "TMPDIR", "USER", "DEVELOPER_DIR"] {
            if let value = base[key] {
                environment[key] = value
            }
        }
        return environment
    }

    private static func execute(
        executableURL: URL,
        arguments: [String],
        directoryURL: URL?,
        environment: [String: String],
        input: Data?,
        timeout: TimeInterval
    ) -> (status: Int32, output: Data)? {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = directoryURL
        process.environment = environment
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        let inputPipe = input == nil ? nil : Pipe()
        process.standardInput = inputPipe ?? FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        if let inputPipe, let input {
            let handle = inputPipe.fileHandleForWriting
            // Report EPIPE instead of raising SIGPIPE if git exits before reading everything.
            _ = fcntl(handle.fileDescriptor, F_SETNOSIGPIPE, 1)
            // Write from another thread so a full output pipe cannot deadlock the input write.
            DispatchQueue.global(qos: .userInitiated).async {
                try? handle.write(contentsOf: input)
                try? handle.close()
            }
        }

        let timeoutItem = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeoutItem.cancel()

        guard process.terminationReason == .exit else {
            return nil
        }
        return (process.terminationStatus, output)
    }
}
