import Foundation

/// Watches a repository's git directories and reports changes to `HEAD`, the index,
/// and refs so that commits, staging, and branch switches refresh the diff state.
@MainActor
final class GitReferenceWatcher {
    private let makeEventSource: () -> FileWatchEventSource
    private var eventSources: [FileWatchEventSource] = []
    private var rootURLs: [URL] = []
    private var debounceWorkItem: DispatchWorkItem?

    var onChange: (() -> Void)?

    init(makeEventSource: @escaping () -> FileWatchEventSource = { FSEventsFileWatchEventSource() }) {
        self.makeEventSource = makeEventSource
    }

    /// In a linked worktree, `HEAD` and `index` live in the worktree's git directory while
    /// refs live in the common directory, so both are watched.
    func start(gitDirectoryURL: URL, commonDirectoryURL: URL) throws {
        stop()
        let roots = [gitDirectoryURL, commonDirectoryURL].map(\.skimdownCanonicalFileURL)
        rootURLs = Array(Set(roots))
        let watchedURLs = rootURLs.filter { root in
            !rootURLs.contains { other in other != root && PathSecurity.isFileURL(root, containedIn: other) }
        }

        do {
            for url in watchedURLs {
                let source = makeEventSource()
                try source.start(folderURL: url) { [weak self] eventURLs in
                    DispatchQueue.main.async {
                        self?.handleEvent(urls: eventURLs)
                    }
                }
                eventSources.append(source)
            }
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        eventSources.forEach { $0.stop() }
        eventSources = []
        rootURLs = []
    }

    nonisolated static func isReferenceEvent(url: URL, rootURLs: [URL]) -> Bool {
        let canonicalURL = url.skimdownCanonicalFileURL
        return rootURLs.contains { rootURL in
            guard let relativePath = PathSecurity.relativePath(for: canonicalURL, in: rootURL) else {
                return false
            }
            guard !relativePath.hasSuffix(".lock") else {
                return false
            }
            return relativePath == "HEAD"
                || relativePath == "index"
                || relativePath == "packed-refs"
                || relativePath.hasPrefix("refs/")
        }
    }

    private func handleEvent(urls: [URL]) {
        guard urls.contains(where: { Self.isReferenceEvent(url: $0, rootURLs: rootURLs) }) else {
            return
        }
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    deinit {
        eventSources.forEach { $0.stop() }
    }
}
