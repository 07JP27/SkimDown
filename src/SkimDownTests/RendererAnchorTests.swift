import WebKit
import XCTest
@testable import SkimDown

final class RendererAnchorTests: XCTestCase {
    @MainActor
    func testRendererAssignsHeadingIDsForSectionLinks() async throws {
        let webView = try await renderMarkdown(
            """
            <h2 id="custom-id">Custom Heading</h2>

            ## Content
            ## テスト
            ## External Links
            ## External Links
            """
        )

        let idsJSON = try await evaluateStringJavaScript(
            "JSON.stringify(Array.from(document.querySelectorAll('h2')).map(function (heading) { return heading.id; }))",
            in: webView
        )
        let ids = try JSONDecoder().decode([String].self, from: Data(idsJSON.utf8))

        XCTAssertEqual(ids, ["custom-id", "content-1", "テスト", "external-links", "external-links-1"])
    }

    @MainActor
    func testScrollToAnchorFindsDecodedAndSluggedHeadingIDs() async throws {
        let webView = try await renderMarkdown(
            """
            ## テスト
            ## External Links
            """
        )

        let encodedJapaneseTarget = try await evaluateStringJavaScript(
            """
            window.__skimdownScrolledTo = null;
            Array.from(document.querySelectorAll('h2')).forEach(function (heading) {
              heading.scrollIntoView = function () { window.__skimdownScrolledTo = this.id; };
            });
            window.skimdown.scrollToAnchor('%E3%83%86%E3%82%B9%E3%83%88');
            window.__skimdownScrolledTo;
            """,
            in: webView
        )

        XCTAssertEqual(encodedJapaneseTarget, "テスト")

        let sluggedTarget = try await evaluateStringJavaScript(
            """
            window.__skimdownScrolledTo = null;
            window.skimdown.scrollToAnchor('External%20Links');
            window.__skimdownScrolledTo;
            """,
            in: webView
        )

        XCTAssertEqual(sluggedTarget, "external-links")
    }

    @MainActor
    private func renderMarkdown(_ markdown: String) async throws -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1000), configuration: configuration)
        let navigationDelegate = NavigationFinishedDelegate()
        let navigationFinished = expectation(description: "renderer HTML loads")
        navigationDelegate.onDidFinish = {
            navigationFinished.fulfill()
        }
        navigationDelegate.onDidFail = { error in
            XCTFail("Renderer HTML failed to load: \(error.localizedDescription)")
            navigationFinished.fulfill()
        }
        webView.navigationDelegate = navigationDelegate

        webView.loadHTMLString(try rendererHTML(markdown: markdown), baseURL: Bundle.main.bundleURL)
        await fulfillment(of: [navigationFinished], timeout: 5)
        webView.navigationDelegate = nil

        return webView
    }

    private func rendererHTML(markdown: String) throws -> String {
        let scripts = try [
            "vendor/markdown-it/markdown-it.min.js",
            "vendor/dompurify/purify.min.js",
            "renderer.js"
        ].map(readWebResource).joined(separator: "\n")

        let payload: [String: Any] = [
            "markdown": markdown,
            "baseURL": Bundle.main.bundleURL.absoluteString,
            "rootURL": Bundle.main.bundleURL.absoluteString,
            "localFileScheme": LocalFileSchemeHandler.scheme,
            "theme": "system",
            "fontSize": 16,
            "renderID": 1,
            "restoreScrollY": 0
        ]

        return """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8">
          </head>
          <body>
            <main id="content"></main>
            <script>\(scripts)</script>
            <script>window.skimdown.render(\(try jsonObject(payload)));</script>
          </body>
        </html>
        """
    }

    private func readWebResource(_ relativePath: String) throws -> String {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Web").appendingPathComponent(relativePath) else {
            throw RendererAnchorTestError.missingResource(relativePath)
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    private func jsonObject(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let string = String(data: data, encoding: .utf8) else {
            throw RendererAnchorTestError.invalidJSON
        }
        return string.replacingOccurrences(of: "</", with: "<\\/")
    }

    @MainActor
    private func evaluateStringJavaScript(_ script: String, in webView: WKWebView) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { value, error in
                if let error {
                    continuation.resume(throwing: RendererAnchorTestError.scriptEvaluationFailed(error.localizedDescription))
                    return
                }

                guard let string = value as? String else {
                    continuation.resume(throwing: RendererAnchorTestError.invalidScriptResult)
                    return
                }

                continuation.resume(returning: string)
            }
        }
    }
}

private enum RendererAnchorTestError: Error {
    case missingResource(String)
    case invalidJSON
    case invalidScriptResult
    case scriptEvaluationFailed(String)
}

@MainActor
private final class NavigationFinishedDelegate: NSObject, WKNavigationDelegate {
    var onDidFinish: (() -> Void)?
    var onDidFail: ((Error) -> Void)?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onDidFinish?()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onDidFail?(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onDidFail?(error)
    }
}
