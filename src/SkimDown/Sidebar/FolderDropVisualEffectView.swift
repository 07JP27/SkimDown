import AppKit

@MainActor
final class FolderDropVisualEffectView: NSVisualEffectView {
    var onFolderDropped: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.skimdownFolderURL == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = sender.draggingPasteboard.skimdownFolderURL else {
            return false
        }
        onFolderDropped?(url)
        return true
    }
}
