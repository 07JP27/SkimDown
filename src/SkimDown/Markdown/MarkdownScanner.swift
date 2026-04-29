import Foundation

struct MarkdownScanner {
    static let excludedDirectoryNames: Set<String> = [".git", "node_modules", ".build", "DerivedData"]

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scan(folderURL: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw CocoaError(.fileReadUnknown)
        }

        var markdownFiles: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            let name = url.lastPathComponent
            let isDirectory = values.isDirectory == true
            let isHidden = values.isHidden == true || name.hasPrefix(".")

            if isDirectory {
                if isHidden || Self.excludedDirectoryNames.contains(name) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard !isHidden, url.skimdownIsMarkdownFile else {
                continue
            }

            let canonicalURL = url.skimdownCanonicalFileURL
            if PathSecurity.isFileURL(canonicalURL, containedIn: folderURL) {
                markdownFiles.append(canonicalURL)
            }
        }

        return markdownFiles.sorted {
            ($0.path as NSString).localizedCaseInsensitiveCompare($1.path) == .orderedAscending
        }
    }
}

