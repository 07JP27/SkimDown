import AppKit

@MainActor
final class FolderDropVisualEffectView: NSVisualEffectView {
    var onFolderDropped: ((URL) -> Void)?
    var onFileDropped: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if pasteboard.skimdownFolderURL != nil || pasteboard.skimdownMarkdownFileURL != nil {
            return .copy
        }
        return []
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
