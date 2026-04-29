import Foundation

extension URL {
    var skimdownCanonicalFileURL: URL {
        standardizedFileURL.resolvingSymlinksInPath()
    }

    var skimdownIsMarkdownFile: Bool {
        let ext = pathExtension.lowercased()
        return ext == "md" || ext == "markdown"
    }

    var skimdownDisplayName: String {
        lastPathComponent.isEmpty ? path : lastPathComponent
    }
}

