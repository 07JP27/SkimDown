import Foundation

enum PathSecurity {
    static func isFileURL(_ fileURL: URL, containedIn folderURL: URL) -> Bool {
        let folderPath = folderURL.skimdownCanonicalFileURL.path
        let filePath = fileURL.skimdownCanonicalFileURL.path

        if filePath == folderPath {
            return true
        }

        let prefix = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
        return filePath.hasPrefix(prefix)
    }

    static func relativePath(for fileURL: URL, in folderURL: URL) -> String? {
        guard isFileURL(fileURL, containedIn: folderURL) else {
            return nil
        }

        let folderPath = folderURL.skimdownCanonicalFileURL.path
        let filePath = fileURL.skimdownCanonicalFileURL.path
        if filePath == folderPath {
            return ""
        }

        let prefix = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
        guard filePath.hasPrefix(prefix) else {
            return nil
        }
        return String(filePath.dropFirst(prefix.count))
    }

    static func folderKey(for folderURL: URL) -> String {
        folderURL.skimdownCanonicalFileURL.path
    }
}

