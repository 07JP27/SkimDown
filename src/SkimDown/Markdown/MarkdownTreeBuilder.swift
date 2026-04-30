import Foundation

struct MarkdownTreeBuilder {
    func buildTree(folderURL: URL, markdownFiles: [URL]) -> [MarkdownTreeItem] {
        let root = MarkdownTreeItem(name: folderURL.lastPathComponent, url: folderURL, relativePath: "", isDirectory: true)

        for fileURL in markdownFiles {
            guard let relativePath = PathSecurity.relativePath(for: fileURL, in: folderURL), !relativePath.isEmpty else {
                continue
            }
            insert(fileURL: fileURL, relativePath: relativePath, into: root, folderURL: folderURL)
        }

        sortRecursively(root)
        return root.children
    }

    private func insert(fileURL: URL, relativePath: String, into root: MarkdownTreeItem, folderURL: URL) {
        let components = relativePath.split(separator: "/").map(String.init)
        guard !components.isEmpty else {
            return
        }

        var parent = root
        var accumulated: [String] = []

        for component in components.dropLast() {
            accumulated.append(component)
            let directoryRelativePath = accumulated.joined(separator: "/")
            if let existing = parent.children.first(where: { $0.isDirectory && $0.name == component }) {
                parent = existing
            } else {
                let directoryURL = folderURL.appendingPathComponent(directoryRelativePath, isDirectory: true)
                let item = MarkdownTreeItem(name: component, url: directoryURL, relativePath: directoryRelativePath, isDirectory: true)
                item.parent = parent
                parent.children.append(item)
                parent = item
            }
        }

        let fileName = components[components.count - 1]
        let fileItem = MarkdownTreeItem(name: fileName, url: fileURL, relativePath: relativePath, isDirectory: false)
        fileItem.parent = parent
        parent.children.append(fileItem)
    }

    private func sortRecursively(_ item: MarkdownTreeItem) {
        item.children.sort { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return (lhs.name as NSString).localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        item.children.forEach(sortRecursively)
    }
}

