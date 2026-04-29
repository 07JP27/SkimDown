import Foundation

final class FolderSession {
    let folderURL: URL
    var treeItems: [MarkdownTreeItem]
    var markdownFiles: [URL]
    var selectedFileURL: URL?
    var securityAccess: SecurityScopedAccess?

    init(folderURL: URL, treeItems: [MarkdownTreeItem] = [], markdownFiles: [URL] = [], selectedFileURL: URL? = nil, securityAccess: SecurityScopedAccess? = nil) {
        self.folderURL = folderURL.standardizedFileURL
        self.treeItems = treeItems
        self.markdownFiles = markdownFiles.map(\.standardizedFileURL)
        self.selectedFileURL = selectedFileURL?.standardizedFileURL
        self.securityAccess = securityAccess
    }

    var markdownCount: Int {
        markdownFiles.count
    }
}

