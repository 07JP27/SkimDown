import Foundation

enum LinkRoute: Equatable {
    case anchor(String)
    case markdownFile(URL, anchor: String?)
    case external(URL)
    case localResource(URL)
    case blocked
}

struct LinkRouter {
    func route(href: String, currentFileURL: URL, folderURL: URL, markdownFiles: Set<URL>) -> LinkRoute {
        guard !href.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .blocked
        }

        if href.hasPrefix("#") {
            return .anchor(String(href.dropFirst()))
        }

        let components = URLComponents(string: href)
        let anchor = components?.fragment

        if let scheme = components?.scheme?.lowercased(), !scheme.isEmpty {
            if ["http", "https", "mailto"].contains(scheme), let url = URL(string: href) {
                return .external(url)
            }

            if scheme == "file", let url = URL(string: href) {
                return routeLocalFile(url.skimdownCanonicalFileURL, folderURL: folderURL, markdownFiles: markdownFiles, anchor: anchor)
            }

            return .blocked
        }

        var pathOnly = href
        if let fragmentIndex = pathOnly.firstIndex(of: "#") {
            pathOnly = String(pathOnly[..<fragmentIndex])
        }

        guard let decodedPath = pathOnly.removingPercentEncoding else {
            return .blocked
        }

        let baseURL = currentFileURL.deletingLastPathComponent()
        let resolvedURL = URL(fileURLWithPath: decodedPath, relativeTo: baseURL).standardizedFileURL.skimdownCanonicalFileURL
        return routeLocalFile(resolvedURL, folderURL: folderURL, markdownFiles: markdownFiles, anchor: anchor)
    }

    private func routeLocalFile(_ fileURL: URL, folderURL: URL, markdownFiles: Set<URL>, anchor: String?) -> LinkRoute {
        guard PathSecurity.isFileURL(fileURL, containedIn: folderURL) else {
            return .blocked
        }

        if fileURL.skimdownIsMarkdownFile, markdownFiles.contains(fileURL.skimdownCanonicalFileURL) {
            return .markdownFile(fileURL.skimdownCanonicalFileURL, anchor: anchor)
        }

        return .localResource(fileURL.skimdownCanonicalFileURL)
    }
}

