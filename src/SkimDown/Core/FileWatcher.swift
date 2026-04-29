import Darwin
import Foundation

@MainActor
final class FileWatcher {
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
        try installDirectoryWatches(folderURL: folderURL)
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
                try? self.installDirectoryWatches(folderURL: rootURL)
            }
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func installDirectoryWatches(folderURL: URL) throws {
        cancelDirectoryWatches()

        let directories = try watchedDirectories(folderURL: folderURL)
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

    private func watchedDirectories(folderURL: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
        var directories = [folderURL]

        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return directories
        }

        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
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
