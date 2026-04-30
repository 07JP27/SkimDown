import Darwin
import Foundation

@MainActor
final class FileWatcher {
    nonisolated static let maxWatchedDirectories = 128

    private struct DirectoryWatch {
        let descriptor: CInt
        let source: DispatchSourceFileSystemObject
    }

    private var rootURL: URL?
    private var watches: [DirectoryWatch] = []
    private var debounceWorkItem: DispatchWorkItem?

    var onChange: (() -> Void)?

    func start(folderURL: URL) throws {
        stop()
        rootURL = folderURL
        installDirectoryWatches(folderURL: folderURL)
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        cancelDirectoryWatches()
        rootURL = nil
    }

    private func scheduleChangeNotification() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            self.onChange?()
            if let rootURL = self.rootURL {
                self.installDirectoryWatches(folderURL: rootURL)
            }
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func installDirectoryWatches(folderURL: URL) {
        cancelDirectoryWatches()

        let directories = Self.watchedDirectories(folderURL: folderURL)
        for directory in directories {
            let descriptor = open(directory.path, O_EVTONLY)
            guard descriptor >= 0 else {
                continue
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .delete, .rename, .extend, .attrib],
                queue: .main
            )

            source.setEventHandler { [weak self] in
                self?.scheduleChangeNotification()
            }
            source.setCancelHandler {
                close(descriptor)
            }
            watches.append(DirectoryWatch(descriptor: descriptor, source: source))
            source.resume()
        }
    }

    nonisolated static func watchedDirectories(
        folderURL: URL,
        limit: Int = maxWatchedDirectories,
        fileManager: FileManager = .default
    ) -> [URL] {
        guard limit > 0 else {
            return []
        }

        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
        var directories = [folderURL]

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return directories
        }

        for case let url as URL in enumerator {
            guard directories.count < limit else {
                break
            }

            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: Set(keys))
            } catch {
                continue
            }

            guard values.isDirectory == true else {
                continue
            }

            let name = url.lastPathComponent
            if values.isHidden == true || name.hasPrefix(".") || MarkdownScanner.excludedDirectoryNames.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            directories.append(url)
        }

        return directories
    }

    private func cancelDirectoryWatches() {
        watches.forEach { $0.source.cancel() }
        watches.removeAll()
    }

    deinit {}
}
