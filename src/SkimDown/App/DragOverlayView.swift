import AppKit

/// Transparent overlay that intercepts folder drag & drop while
/// passing all normal mouse events through to views underneath.
///
/// WindowServer dispatches D&D based on registeredDraggedTypes and
/// Z-order, not hitTest. By returning nil from hitTest, clicks and
/// scrolls pass through to the WKWebView beneath, but D&D events
/// are captured by this view because it sits on top in Z-order.
@MainActor
final class DragOverlayView: NSView {
    var onFolderDropped: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        folderURL(from: sender.draggingPasteboard) == nil ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        folderURL(from: sender.draggingPasteboard) == nil ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        // no visual state to reset
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = folderURL(from: sender.draggingPasteboard) else {
            return false
        }
        onFolderDropped?(url)
        return true
    }

    private func folderURL(from pasteboard: NSPasteboard) -> URL? {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else {
            return nil
        }

        return urls.first { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }
}
