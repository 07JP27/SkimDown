import CoreServices
import Foundation

@MainActor
final class FileWatcher {
    private var rootURL: URL?
    private let eventSource: FileWatchEventSource
    private var debounceWorkItem: DispatchWorkItem?

    var onChange: (() -> Void)?

    init(eventSource: FileWatchEventSource = FSEventsFileWatchEventSource()) {
        self.eventSource = eventSource
    }

    func start(folderURL: URL) throws {
        stop()
        rootURL = folderURL
        try eventSource.start(folderURL: folderURL) { [weak self] eventURLs in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.handleEvent(urls: eventURLs)
            }
        }
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        eventSource.stop()
        rootURL = nil
    }

    nonisolated static func shouldIgnoreEvent(url: URL, rootURL: URL) -> Bool {
        let canonicalURL = url.skimdownCanonicalFileURL
        let canonicalRootURL = rootURL.skimdownCanonicalFileURL
        guard PathSecurity.isFileURL(canonicalURL, containedIn: canonicalRootURL),
              let relativePath = PathSecurity.relativePath(for: canonicalURL, in: canonicalRootURL) else {
            return true
        }

        let components = relativePath.split(separator: "/").map(String.init)
        return components.contains { component in
            component.hasPrefix(".") || MarkdownScanner.excludedDirectoryNames.contains(component)
        }
    }

    private func handleEvent(urls: [URL]) {
        guard let rootURL else {
            return
        }

        if urls.contains(where: { !Self.shouldIgnoreEvent(url: $0, rootURL: rootURL) }) {
            scheduleChangeNotification()
        }
    }

    private func scheduleChangeNotification() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            self.onChange?()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    deinit {
        eventSource.stop()
    }
}

protocol FileWatchEventSource: AnyObject, Sendable {
    func start(folderURL: URL, onEvent: @escaping ([URL]) -> Void) throws
    func stop()
}

private final class FSEventsFileWatchEventSource: FileWatchEventSource, @unchecked Sendable {
    private final class CallbackBox {
        let onEvent: ([URL]) -> Void

        init(onEvent: @escaping ([URL]) -> Void) {
            self.onEvent = onEvent
        }
    }

    private var stream: FSEventStreamRef?
    private var retainedCallbackBox: Unmanaged<CallbackBox>?
    private let queue = DispatchQueue(label: "dev.skimdown.filewatcher.fsevents")

    func start(folderURL: URL, onEvent: @escaping ([URL]) -> Void) throws {
        stop()

        let callbackBox = CallbackBox(onEvent: onEvent)
        let retained = Unmanaged.passRetained(callbackBox)
        var context = FSEventStreamContext(
            version: 0,
            info: retained.toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, contextInfo, eventCount, eventPaths, _, _ in
                guard let contextInfo else {
                    return
                }

                let box = Unmanaged<CallbackBox>.fromOpaque(contextInfo).takeUnretainedValue()
                let paths = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
                var urls: [URL] = []
                urls.reserveCapacity(eventCount)

                for index in 0..<eventCount {
                    urls.append(URL(fileURLWithPath: String(cString: paths[index])))
                }

                box.onEvent(urls)
            },
            &context,
            [folderURL.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        ) else {
            retained.release()
            throw CocoaError(.fileReadUnknown)
        }

        FSEventStreamSetDispatchQueue(stream, queue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            retained.release()
            throw CocoaError(.fileReadUnknown)
        }

        self.retainedCallbackBox = retained
        self.stream = stream
    }

    func stop() {
        guard let stream else {
            retainedCallbackBox?.release()
            retainedCallbackBox = nil
            return
        }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        // Drain pending callbacks before releasing the box
        queue.sync {}
        retainedCallbackBox?.release()
        retainedCallbackBox = nil
    }
}
