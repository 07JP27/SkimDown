import Foundation

/// Coordinates read-only Git lookups for one window. Git commands run on a private
/// serial queue; results are delivered on the main actor.
@MainActor
final class GitChangeTracker {
    private final class State: @unchecked Sendable {
        // Accessed only on `queue`.
        var repository: GitRepository?
        var snapshot: GitHeadSnapshot?

        func currentSnapshot() -> GitHeadSnapshot? {
            guard let repository else {
                return nil
            }
            if let snapshot {
                return snapshot
            }
            let snapshot = repository.loadSnapshot()
            self.snapshot = snapshot
            return snapshot
        }
    }

    private let queue = DispatchQueue(label: "dev.skimdown.git", qos: .userInitiated)
    private let state = State()
    private let referenceWatcher = GitReferenceWatcher()
    private var generation = 0
    private(set) var folderURL: URL?

    /// Called after `HEAD`, refs, or the index change.
    var onRepositoryChange: (() -> Void)?

    var isActive: Bool {
        folderURL != nil
    }

    init() {
        referenceWatcher.onChange = { [weak self] in
            self?.repositoryDidChange()
        }
    }

    /// Starts tracking when `folderURL` directly contains `.git`. Git is not launched otherwise.
    func start(folderURL: URL) {
        let folderURL = folderURL.skimdownCanonicalFileURL
        guard folderURL != self.folderURL else {
            return
        }
        stop()
        guard GitRepository.hasGitEntry(in: folderURL) else {
            return
        }

        self.folderURL = folderURL
        let generation = self.generation
        let state = self.state
        queue.async {
            state.repository = GitRepository.open(folderURL: folderURL)
            state.snapshot = nil
            let directories = state.repository.map { ($0.gitDirectoryURL, $0.commonDirectoryURL) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == generation, let directories else {
                    return
                }
                try? self.referenceWatcher.start(gitDirectoryURL: directories.0, commonDirectoryURL: directories.1)
            }
        }
    }

    func stop() {
        generation += 1
        folderURL = nil
        referenceWatcher.stop()
        let state = self.state
        queue.async {
            state.repository = nil
            state.snapshot = nil
        }
    }

    func fileStatuses(relativePaths: [String], completion: @escaping @MainActor @Sendable ([String: GitFileStatus]) -> Void) {
        guard isActive else {
            completion([:])
            return
        }
        let generation = self.generation
        let state = self.state
        queue.async {
            let statuses = state.currentSnapshot().flatMap { snapshot in
                state.repository?.statuses(forRelativePaths: relativePaths, snapshot: snapshot)
            } ?? [:]
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == generation else {
                    return
                }
                completion(statuses)
            }
        }
    }

    /// Delivers the line hunks between the base text and `markdown`, or nil when there is nothing to show.
    func diffHunks(fileURL: URL, markdown: String, completion: @escaping @MainActor @Sendable ([LineDiffHunk]?) -> Void) {
        guard let folderURL,
              let relativePath = PathSecurity.relativePath(for: fileURL, in: folderURL),
              !relativePath.isEmpty else {
            completion(nil)
            return
        }
        let state = self.state
        queue.async {
            let hunks = state.currentSnapshot()
                .flatMap { snapshot in state.repository?.baseText(forRelativePath: relativePath, snapshot: snapshot) }
                .map { LineDiff.hunks(old: $0, new: markdown) }
            DispatchQueue.main.async {
                completion(hunks?.isEmpty == false ? hunks : nil)
            }
        }
    }

    private func repositoryDidChange() {
        let state = self.state
        queue.async {
            state.snapshot = nil
        }
        onRepositoryChange?()
    }
}
