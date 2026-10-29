import WebKit
import XCTest
@testable import SkimDown

final class RendererGitDiffTests: XCTestCase {
    private static let blocksMarkdown = """
    # Title

    Unchanged para.

    New paragraph.

    Changed para.

    - parent changed
      - child same
      - child new

    | A | B |
    | - | - |
    | 1 | 2 |
    | 3 | 4 |

    ```js
    let x = 1
    ```
    """

    private static let blocksHunks = [
        LineDiffHunk(newStart: 2, newCount: 0, oldStart: 2, oldCount: 2, oldLines: ["Removed paragraph.", ""]),
        LineDiffHunk(newStart: 4, newCount: 2, oldStart: 4, oldCount: 0, oldLines: []),
        LineDiffHunk(newStart: 6, newCount: 1, oldStart: 4, oldCount: 1, oldLines: ["Old para."]),
        LineDiffHunk(newStart: 8, newCount: 1, oldStart: 6, oldCount: 1, oldLines: ["- parent"]),
        LineDiffHunk(newStart: 10, newCount: 1, oldStart: 8, oldCount: 0, oldLines: []),
        LineDiffHunk(newStart: 15, newCount: 1, oldStart: 12, oldCount: 1, oldLines: ["| 3 | 5 |"]),
        LineDiffHunk(newStart: 18, newCount: 1, oldStart: 15, oldCount: 1, oldLines: ["let x = 0"])
    ]

    private static let inspectionScript = """
    (function () {
      function gitClass(element) {
        if (!element) { return "missing"; }
        return Array.from(element.classList).filter(function (name) {
          return name === "skimdown-git-added" || name === "skimdown-git-modified";
        }).join(" ");
      }
      function markerBefore(element) {
        var previous = element && element.previousElementSibling;
        if (!previous) { return ""; }
        var details = previous.matches(".skimdown-git-marker")
          ? previous
          : previous.querySelector(":scope > .skimdown-git-marker, :scope > td > .skimdown-git-marker");
        if (!details) { return ""; }
        return [
          previous.tagName,
          details.classList.contains("skimdown-git-marker-deleted") ? "deleted" : "modified",
          details.querySelector("summary").textContent,
          details.querySelector("pre").textContent
        ].join("|");
      }
      function byText(selector, text) {
        return Array.from(document.querySelectorAll(selector)).find(function (element) {
          var first = element.firstChild;
          while (first && first.nodeType === Node.TEXT_NODE && !first.textContent.trim()) {
            first = first.nextSibling;
          }
          return first && first.textContent.trim() === text;
        });
      }
      var result = {};
      INSPECT
      return JSON.stringify(result);
    })();
    """

    @MainActor
    func testRendererClassifiesBlocksAndInsertsPreviousTextMarkers() async throws {
        let webView = try await renderMarkdown(Self.blocksMarkdown, gitDiffHunks: Self.blocksHunks)

        let result = try await inspect(
            """
            result.heading = gitClass(document.querySelector("h1"));
            result.unchanged = gitClass(byText("p", "Unchanged para."));
            result.unchangedMarker = markerBefore(byText("p", "Unchanged para."));
            result.added = gitClass(byText("p", "New paragraph."));
            result.addedMarker = markerBefore(byText("p", "New paragraph."));
            result.changed = gitClass(byText("p", "Changed para."));
            result.changedMarker = markerBefore(byText("p", "Changed para."));
            result.parentItem = gitClass(byText("li", "parent changed"));
            result.parentItemMarker = markerBefore(byText("li", "parent changed"));
            result.childSame = gitClass(byText("li", "child same"));
            result.childNew = gitClass(byText("li", "child new"));
            result.headerRow = gitClass(document.querySelector("thead tr"));
            result.firstRow = gitClass(byText("tbody tr", "1"));
            result.changedRow = gitClass(byText("tbody tr", "3"));
            result.changedRowMarker = markerBefore(byText("tbody tr", "3"));
            result.markerColSpan = String(document.querySelector(".skimdown-git-marker-row td").colSpan);
            result.code = gitClass(document.querySelector("pre:not(.skimdown-git-previous)"));
            result.codeElement = gitClass(document.querySelector("pre > code"));
            result.codeMarker = markerBefore(document.querySelector("pre:not(.skimdown-git-previous)"));
            result.leftoverAnchors = String(document.querySelectorAll("[class*='skimdown-git-anchor-'], .skimdown-git-sentinel").length);
            """,
            in: webView
        )

        XCTAssertEqual(result, [
            "heading": "",
            "unchanged": "",
            "unchangedMarker": "DETAILS|deleted|2 lines deleted|Removed paragraph.\n",
            "added": "skimdown-git-added",
            "addedMarker": "",
            "changed": "skimdown-git-modified",
            "changedMarker": "DETAILS|modified|Show previous version|Old para.",
            "parentItem": "skimdown-git-modified",
            "parentItemMarker": "LI|modified|Show previous version|- parent",
            "childSame": "",
            "childNew": "skimdown-git-added",
            "headerRow": "",
            "firstRow": "",
            "changedRow": "skimdown-git-modified",
            "changedRowMarker": "TR|modified|Show previous version|| 3 | 5 |",
            "markerColSpan": "2",
            "code": "skimdown-git-modified",
            "codeElement": "",
            "codeMarker": "DETAILS|modified|Show previous version|let x = 0",
            "leftoverAnchors": "0"
        ])
    }

    @MainActor
    func testRendererKeepsClassesOnFrontMatterMermaidMathAndHTML() async throws {
        let markdown = """
        ---
        title: New
        ---

        ```mermaid
        graph TD
        ```

        ```math
        x^2
        ```

        <div>Raw HTML</div>
        """
        let hunks = [
            LineDiffHunk(newStart: 1, newCount: 1, oldStart: 1, oldCount: 1, oldLines: ["title: Old"]),
            LineDiffHunk(newStart: 4, newCount: 3, oldStart: 4, oldCount: 0, oldLines: []),
            LineDiffHunk(newStart: 9, newCount: 1, oldStart: 6, oldCount: 1, oldLines: ["x^1"]),
            LineDiffHunk(newStart: 12, newCount: 1, oldStart: 8, oldCount: 0, oldLines: [])
        ]
        let webView = try await renderMarkdown(markdown, gitDiffHunks: hunks, additionalScripts: [Self.mermaidStubScript])
        try await waitForJavaScriptCondition("document.querySelector('.mermaid-container svg')", in: webView)

        let result = try await inspect(
            """
            result.frontMatter = gitClass(document.querySelector(".skimdown-frontmatter"));
            result.frontMatterMarker = markerBefore(document.querySelector(".skimdown-frontmatter"));
            result.mermaid = gitClass(document.querySelector(".mermaid-container"));
            result.math = gitClass(document.querySelector(".skimdown-math-block"));
            result.mathMarker = markerBefore(document.querySelector(".skimdown-math-block"));
            result.html = gitClass(byText("div", "Raw HTML"));
            """,
            in: webView
        )

        XCTAssertEqual(result, [
            "frontMatter": "skimdown-git-modified",
            "frontMatterMarker": "DETAILS|modified|Show previous version|title: Old",
            "mermaid": "skimdown-git-added",
            "math": "skimdown-git-modified",
            "mathMarker": "DETAILS|modified|Show previous version|x^1",
            "html": "skimdown-git-added"
        ])
    }

    @MainActor
    func testUntrackedDocumentIsAddedWithoutMarkers() async throws {
        let markdown = "# Notes\n\nBody text.\n\n- item\n"
        let webView = try await renderMarkdown(markdown, gitDiffHunks: LineDiff.hunks(old: "", new: markdown))

        let result = try await inspect(
            """
            result.heading = gitClass(document.querySelector("h1"));
            result.paragraph = gitClass(document.querySelector("p"));
            result.item = gitClass(document.querySelector("li"));
            result.markers = String(document.querySelectorAll(".skimdown-git-marker").length);
            """,
            in: webView
        )

        XCTAssertEqual(result, [
            "heading": "skimdown-git-added",
            "paragraph": "skimdown-git-added",
            "item": "skimdown-git-added",
            "markers": "0"
        ])
    }

    @MainActor
    func testSearchSkipsPreviousTextInMarkers() async throws {
        let hunks = [LineDiffHunk(newStart: 1, newCount: 0, oldStart: 1, oldCount: 1, oldLines: ["alpha removed"])]
        let webView = try await renderMarkdown("Keep alpha.\n", gitDiffHunks: hunks)

        let resultJSON = try await evaluateStringJavaScript(
            """
            JSON.stringify({
              markerText: document.querySelector(".skimdown-git-marker pre").textContent,
              count: window.skimdown.performSearch("alpha", false, false).count
            })
            """,
            in: webView
        )
        let result = try JSONDecoder().decode(SearchResultPayload.self, from: Data(resultJSON.utf8))

        XCTAssertEqual(result.markerText, "alpha removed")
        XCTAssertEqual(result.count, 1)
    }

    @MainActor
    func testGutterBarsShareOneColumnAndJoinConsecutiveChanges() async throws {
        let markdown = """
        # Added heading

        Added paragraph.

        ```js
        let x = 1
        ```

        Unchanged paragraph.

        - parent changed
          - child same
          - child new

        | A | B |
        | - | - |
        | 1 | 2 |
        | 3 | 4 |

        Keep.
        """
        let hunks = [
            LineDiffHunk(newStart: 0, newCount: 7, oldStart: 0, oldCount: 0, oldLines: []),
            LineDiffHunk(newStart: 10, newCount: 1, oldStart: 3, oldCount: 1, oldLines: ["- parent"]),
            LineDiffHunk(newStart: 12, newCount: 1, oldStart: 5, oldCount: 0, oldLines: []),
            LineDiffHunk(newStart: 17, newCount: 1, oldStart: 10, oldCount: 1, oldLines: ["| 3 | 5 |"]),
            LineDiffHunk(newStart: 19, newCount: 0, oldStart: 12, oldCount: 1, oldLines: ["Removed."])
        ]
        let webView = try await renderMarkdown(markdown, gitDiffHunks: hunks, includeStyles: true)
        // Rendering updates (ResizeObserver, requestAnimationFrame) only run for a visible web view.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 1000), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.orderFrontRegardless()
        defer { window.close() }

        let result = try await inspect(
            """
            var bars = Array.from(document.querySelectorAll(".skimdown-git-gutter > .skimdown-git-gutter-bar")).map(function (bar) {
              var r = bar.getBoundingClientRect();
              var state = ["added", "modified", "deleted"].find(function (name) {
                return bar.classList.contains("skimdown-git-gutter-" + name);
              });
              return { state: state, left: r.left, right: r.right, width: r.width, top: r.top, bottom: r.bottom };
            }).sort(function (a, b) { return a.top - b.top; });
            function rect(element) { return element.getBoundingClientRect(); }
            function near(a, b) { return Math.abs(a - b) < 1; }
            var parent = byText("li", "parent changed");
            var changedRow = byText("tbody tr", "3");
            var h1 = rect(document.querySelector("h1"));
            var code = rect(document.querySelector("pre:not(.skimdown-git-previous)"));
            var unchanged = rect(byText("p", "Unchanged paragraph."));
            var childNew = rect(byText("li", "child new"));
            var deletion = rect(document.querySelector("details.skimdown-git-marker-deleted"));
            result.states = bars.map(function (bar) { return bar.state; }).join(",");
            result.sameColumn = String(bars.every(function (bar) { return near(bar.left, bars[0].left) && near(bar.width, 3); }));
            result.outsideContent = String(bars[0].right <= rect(document.getElementById("content")).left);
            result.headingToCode = String(near(bars[0].top, h1.top) && near(bars[0].bottom, code.bottom));
            result.unchangedUncovered = String(bars[0].bottom <= unchanged.top && bars[1].top >= unchanged.bottom);
            result.parentWithMarker = String(near(bars[1].top, rect(parent.previousElementSibling).top) &&
              near(bars[1].bottom, rect(parent.querySelector("ul")).top));
            result.childNew = String(near(bars[2].top, childNew.top) && near(bars[2].bottom, childNew.bottom));
            result.rowWithMarker = String(near(bars[3].top, rect(changedRow.previousElementSibling).top) &&
              near(bars[3].bottom, rect(changedRow).bottom));
            result.deletion = String(near(bars[4].top, deletion.top) && near(bars[4].bottom, deletion.bottom));
            window.skimdownDeletionBarTop = bars[4].top;
            """,
            in: webView
        )

        XCTAssertEqual(result, [
            "states": "added,modified,added,modified,deleted",
            "sameColumn": "true",
            "outsideContent": "true",
            "headingToCode": "true",
            "unchangedUncovered": "true",
            "parentWithMarker": "true",
            "childNew": "true",
            "rowWithMarker": "true",
            "deletion": "true"
        ])

        _ = try await evaluateStringJavaScript(
            "document.querySelector('.skimdown-git-marker-item details').open = true; 'opened'",
            in: webView
        )
        try await waitForJavaScriptCondition(
            """
            Array.from(document.querySelectorAll('.skimdown-git-gutter-deleted')).some(function (bar) {
              return bar.getBoundingClientRect().top > window.skimdownDeletionBarTop + 5;
            })
            """,
            in: webView
        )
    }

    @MainActor
    func testRendererAddsNoGitClassesWithoutGitDiff() async throws {
        let webView = try await renderMarkdown(Self.blocksMarkdown, gitDiffHunks: nil)

        let count = try await evaluateStringJavaScript(
            "String(document.querySelectorAll(\"[class*='skimdown-git-'], .skimdown-git-marker\").length)",
            in: webView
        )

        XCTAssertEqual(count, "0")
    }

    // MARK: - Helpers

    private static let mermaidStubScript = """
    window.mermaid = {
      initialize: function () {},
      run: function (options) {
        (options.nodes || []).forEach(function (node) {
          node.innerHTML = '<svg viewBox="0 0 10 10" xmlns="http://www.w3.org/2000/svg"></svg>';
        });
        return Promise.resolve();
      }
    };
    """

    @MainActor
    private func inspect(_ statements: String, in webView: WKWebView) async throws -> [String: String] {
        let script = Self.inspectionScript.replacingOccurrences(of: "INSPECT", with: statements)
        let resultJSON = try await evaluateStringJavaScript(script, in: webView)
        return try JSONDecoder().decode([String: String].self, from: Data(resultJSON.utf8))
    }

    @MainActor
    private func renderMarkdown(
        _ markdown: String,
        gitDiffHunks: [LineDiffHunk]?,
        additionalScripts: [String] = [],
        includeStyles: Bool = false
    ) async throws -> WKWebView {
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1000))
        let navigationDelegate = GitDiffNavigationDelegate()
        let navigationFinished = expectation(description: "renderer HTML loads")
        navigationDelegate.onFinish = { error in
            if let error {
                XCTFail("Renderer HTML failed to load: \(error.localizedDescription)")
            }
            navigationFinished.fulfill()
        }
        webView.navigationDelegate = navigationDelegate

        var payload: [String: Any] = [
            "markdown": markdown,
            "baseURL": Bundle.main.bundleURL.absoluteString,
            "rootURL": Bundle.main.bundleURL.absoluteString,
            "localFileScheme": LocalFileSchemeHandler.scheme,
            "theme": "system",
            "fontSize": 16,
            "renderID": 1,
            "restoreScrollY": 0,
            "reservedTrailingWidth": 0
        ]
        if let gitDiffHunks {
            payload["gitDiff"] = MarkdownWebView.gitDiffPayload(gitDiffHunks)
        }
        let scripts = try (
            ["vendor/markdown-it/markdown-it.min.js", "vendor/dompurify/purify.min.js"].map(readWebResource)
            + additionalScripts
            + [readWebResource("renderer.js")]
        ).joined(separator: "\n")
        let payloadJSON = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
            .replacingOccurrences(of: "</", with: "<\\/")
        let styles = includeStyles ? "<style>\(try readWebResource("skimdown.css"))</style>" : ""

        webView.loadHTMLString(
            """
            <!doctype html>
            <html>
              <head><meta charset="utf-8">\(styles)</head>
              <body>
                <main id="content"></main>
                <script>\(scripts)</script>
                <script>window.skimdown.render(\(payloadJSON));</script>
              </body>
            </html>
            """,
            baseURL: Bundle.main.bundleURL
        )
        await fulfillment(of: [navigationFinished], timeout: 5)
        webView.navigationDelegate = nil
        return webView
    }

    private func readWebResource(_ relativePath: String) throws -> String {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Web").appendingPathComponent(relativePath) else {
            throw RendererGitDiffTestError.missingResource(relativePath)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    @MainActor
    private func evaluateStringJavaScript(_ script: String, in webView: WKWebView) async throws -> String {
        let value = try await webView.evaluateJavaScript(script)
        guard let string = value as? String else {
            throw RendererGitDiffTestError.invalidScriptResult
        }
        return string
    }

    @MainActor
    private func waitForJavaScriptCondition(_ script: String, in webView: WKWebView) async throws {
        let timeout = Date().addingTimeInterval(2)
        while Date() < timeout {
            if try await evaluateStringJavaScript("String(Boolean(\(script)))", in: webView) == "true" {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw RendererGitDiffTestError.timedOut(script)
    }
}

private enum RendererGitDiffTestError: Error {
    case missingResource(String)
    case invalidScriptResult
    case timedOut(String)
}

private struct SearchResultPayload: Decodable {
    let markerText: String
    let count: Int
}

@MainActor
private final class GitDiffNavigationDelegate: NSObject, WKNavigationDelegate {
    var onFinish: ((Error?) -> Void)?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onFinish?(nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onFinish?(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onFinish?(error)
    }
}
