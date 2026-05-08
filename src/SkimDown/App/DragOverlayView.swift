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
    var onFileDropped: ((URL) -> Void)?

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

    private func dragOperation(for pasteboard: NSPasteboard) -> NSDragOperation {
        if pasteboard.skimdownFolderURL != nil || pasteboard.skimdownMarkdownFileURL != nil {
            return .copy
        }
        return []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragOperation(for: sender.draggingPasteboard)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragOperation(for: sender.draggingPasteboard)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        // no visual state to reset
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let folderURL = pasteboard.skimdownFolderURL {
            onFolderDropped?(folderURL)
            return true
        }
        if let fileURL = pasteboard.skimdownMarkdownFileURL {
            onFileDropped?(fileURL)
            return true
        }
        return false
    }
}
