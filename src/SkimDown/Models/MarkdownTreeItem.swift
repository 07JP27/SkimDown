import Foundation

final class MarkdownTreeItem: NSObject {
    let name: String
    let url: URL
    let relativePath: String
    let isDirectory: Bool
    weak var parent: MarkdownTreeItem?
    var children: [MarkdownTreeItem]

    init(name: String, url: URL, relativePath: String, isDirectory: Bool, children: [MarkdownTreeItem] = []) {
        self.name = name
        self.url = url.standardizedFileURL
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.children = children
    }

    var fileURL: URL? {
        isDirectory ? nil : url
    }

    var allFileItems: [MarkdownTreeItem] {
        if !isDirectory {
            return [self]
        }
        return children.flatMap(\.allFileItems)
    }
}

