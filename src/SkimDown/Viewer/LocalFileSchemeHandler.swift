import Foundation
import UniformTypeIdentifiers
import WebKit

final class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "skimdown-local"

    private let lock = NSLock()
    private var _rootFolderURL: URL?

    var rootFolderURL: URL? {
        get { lock.withLock { _rootFolderURL } }
        set { lock.withLock { _rootFolderURL = newValue } }
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let request = urlSchemeTask.request
        guard let url = request.url,
              let filePath = url.path.removingPercentEncoding.map({ $0 }) ?? Optional(url.path) else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        let fileURL = URL(fileURLWithPath: filePath)

        guard let root = rootFolderURL,
              PathSecurity.isFileURL(fileURL, containedIn: root) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let mimeType = Self.mimeType(for: fileURL)
            let response = URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // No async work to cancel.
    }

    private static func mimeType(for url: URL) -> String {
        if let utType = UTType(filenameExtension: url.pathExtension), let mime = utType.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
}
