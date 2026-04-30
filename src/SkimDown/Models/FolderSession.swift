import Foundation

final class FolderSession {
    let folderURL: URL
    var treeItems: [MarkdownTreeItem]
    var markdownFiles: [URL]
    var selectedFileURL: URL?

    init(folderURL: URL, treeItems: [MarkdownTreeItem] = [], markdownFiles: [URL] = [], selectedFileURL: URL? = nil) {
        self.folderURL = folderURL.standardizedFileURL
        self.treeItems = treeItems
        self.markdownFiles = markdownFiles.map(\.standardizedFileURL)
        self.selectedFileURL = selectedFileURL?.standardizedFileURL
    }

    var markdownCount: Int {
        markdownFiles.count
    }
}

