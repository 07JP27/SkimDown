import Foundation

enum MarkdownDocumentLoaderError: LocalizedError {
    case invalidUTF8

    var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "This Markdown file is not UTF-8."
        }
    }
}

struct MarkdownDocumentLoader {
    func load(fileURL: URL) throws -> String {
        var data = try Data(contentsOf: fileURL)
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            data.removeFirst(3)
        }

        guard let markdown = String(data: data, encoding: .utf8) else {
            throw MarkdownDocumentLoaderError.invalidUTF8
        }
        return markdown
    }
}

