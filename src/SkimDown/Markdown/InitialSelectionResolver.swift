import Foundation

struct InitialSelectionResolver {
    func resolve(folderURL: URL, markdownFiles: [URL], treeItems: [MarkdownTreeItem], lastRelativePath: String?) -> URL? {
        let fileSet = Set(markdownFiles.map { $0.skimdownCanonicalFileURL })

        if let lastRelativePath {
            let lastURL = folderURL.appendingPathComponent(lastRelativePath).skimdownCanonicalFileURL
            if fileSet.contains(lastURL) {
                return lastURL
            }
        }

        let rootReadme = folderURL.appendingPathComponent("README.md").skimdownCanonicalFileURL
        if fileSet.contains(rootReadme) {
            return rootReadme
        }

        return treeItems.flatMap(\.allFileItems).first?.url
    }
}

