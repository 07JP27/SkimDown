import WebKit
import XCTest
@testable import SkimDown

final class RendererAnchorTests: XCTestCase {
    @MainActor
    func testRendererDecoratesInlineColorCodes() async throws {
        let webView = try await renderMarkdown(
            """
            Inline #0a66d6, short #f80, alpha #8250dfcc, and code `#cf222e`.
            """
        )

        let resultJSON = try await evaluateStringJavaScript(
            """
            JSON.stringify({
              colors: Array.from(document.querySelectorAll('.skimdown-color-code')).map(function (node) {
                return node.childNodes[0].nodeValue;
              }),
              swatchTitles: Array.from(document.querySelectorAll('.skimdown-color-swatch')).map(function (node) {
                return node.title;
              }),
              codeSwatches: document.querySelectorAll('code .skimdown-color-swatch').length
            })
            """,
            in: webView
        )
        let result = try JSONDecoder().decode(ColorCodePreviewResult.self, from: Data(resultJSON.utf8))

        XCTAssertEqual(result.colors, ["#0a66d6", "#f80", "#8250dfcc"])
        XCTAssertEqual(result.swatchTitles, ["#0a66d6", "#f80", "#8250dfcc"])
        XCTAssertEqual(result.codeSwatches, 0)
    }

    @MainActor
    func testSearchMatchesAcrossColorCodePreviewMarkup() async throws {
        let webView = try await renderMarkdown(
            """
            Inline #0a66d6, short #f80, alpha #8250dfcc.
            """
        )

        let resultJSON = try await evaluateStringJavaScript(
            """
            var firstState = window.skimdown.performSearch('Inline #0a66d6', false, false);
            var firstSegments = Array.from(document.querySelectorAll('.skimdown-search-match')).map(function (node) {
              return node.textContent;
            });
            var secondState = window.skimdown.performSearch('#0a66d6, short', false, false);
            var secondSegments = Array.from(document.querySelectorAll('.skimdown-search-match')).map(function (node) {
              return node.textContent;
            });
            JSON.stringify({
              firstCount: firstState.count,
              firstSegments: firstSegments,
              secondCount: secondState.count,
              secondSegments: secondSegments
            })
            """,
            in: webView
        )
        let result = try JSONDecoder().decode(SearchAcrossColorCodeResult.self, from: Data(resultJSON.utf8))

        XCTAssertEqual(result.firstCount, 1)
        XCTAssertEqual(result.firstSegments.joined(), "Inline #0a66d6")
        XCTAssertEqual(result.secondCount, 1)
        XCTAssertEqual(result.secondSegments.joined(), "#0a66d6, short")
    }

    @MainActor
    func testColorCodeDecorationSkipsMermaidSource() async throws {
        let webView = try await renderMarkdown(
            """
            ```mermaid
            graph TD
                A[Start] -->|Yes| B[End]
                style A fill:#f80,stroke:#333
            ```

            Paragraph with #0a66d6 color.
            """
        )

        let resultJSON = try await evaluateStringJavaScript(
            """
            JSON.stringify({
              mermaidSwatches: document.querySelectorAll('.mermaid .skimdown-color-swatch, .mermaid-container .skimdown-color-swatch').length,
              paragraphSwatches: document.querySelectorAll('p .skimdown-color-swatch').length
            })
            """,
            in: webView
        )
        let result = try JSONDecoder().decode(MermaidColorExclusionResult.self, from: Data(resultJSON.utf8))

        XCTAssertEqual(result.mermaidSwatches, 0, "Color decoration must not inject swatches into Mermaid source")
        XCTAssertEqual(result.paragraphSwatches, 1, "Color decoration should still apply outside Mermaid blocks")
    }

    @MainActor
    func testSearchDoesNotMatchAcrossBlockBoundaries() async throws {
        let webView = try await renderMarkdown(
            """
            First paragraph ends with foo.

            Second paragraph starts with bar here.

            This paragraph has foobar together.
            """
        )

        let resultJSON = try await evaluateStringJavaScript(
            """
            var state = window.skimdown.performSearch('foobar', false, false);
            JSON.stringify({ count: state.count })
            """,
            in: webView
        )
        let result = try JSONDecoder().decode(SearchBlockBoundaryResult.self, from: Data(resultJSON.utf8))

        XCTAssertEqual(result.count, 1, "Search must not match across block boundaries; only the literal occurrence should match")
    }

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

private struct ColorCodePreviewResult: Decodable {
    let colors: [String]
    let swatchTitles: [String]
    let codeSwatches: Int
}

private struct SearchAcrossColorCodeResult: Decodable {
    let firstCount: Int
    let firstSegments: [String]
    let secondCount: Int
    let secondSegments: [String]
}

private struct MermaidColorExclusionResult: Decodable {
    let mermaidSwatches: Int
    let paragraphSwatches: Int
}

private struct SearchBlockBoundaryResult: Decodable {
    let count: Int
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
