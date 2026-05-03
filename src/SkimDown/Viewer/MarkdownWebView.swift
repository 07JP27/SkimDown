import AppKit
import WebKit

struct SearchResult {
    let count: Int
    let index: Int
}

@MainActor
protocol MarkdownWebViewDelegate: AnyObject {
    func markdownWebView(_ webView: MarkdownWebView, didRequestLink href: String)
}

@MainActor
final class MarkdownWebView: NSView, WKScriptMessageHandler, WKNavigationDelegate {
    weak var delegate: MarkdownWebViewDelegate?

    private enum WebResourceError: LocalizedError {
        case missing(String)
        case unreadable(String, Error)

        var errorDescription: String? {
            switch self {
            case .missing(let relativePath):
                "Missing bundled Web resource: \(relativePath)"
            case .unreadable(let relativePath, let error):
                "Unable to read bundled Web resource \(relativePath): \(error.localizedDescription)"
            }
        }
    }

    private static var webResourceCache: [String: String] = [:]

    private struct PendingNavigation {
        let navigation: WKNavigation
        let generation: Int
        let scrollY: Double?
        let completion: (() -> Void)?
    }

    private let webView: WKWebView
    private var renderGeneration = 0
    private var pendingNavigation: PendingNavigation?

    override init(frame frameRect: NSRect) {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        configuration.userContentController = userContentController
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frameRect)

        userContentController.add(WeakScriptMessageHandler(delegate: self), name: "linkClick")
        userContentController.add(WeakScriptMessageHandler(delegate: self), name: "copyCode")

        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = false
        addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        let userContentController = webView.configuration.userContentController
        userContentController.removeScriptMessageHandler(forName: "linkClick")
        userContentController.removeScriptMessageHandler(forName: "copyCode")
    }

    func render(
        markdown: String,
        currentFileURL: URL,
        rootFolderURL: URL,
        theme: AppTheme,
        fontSize: Double,
        preserveScrollPosition: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        let generation = advanceRenderGeneration()
        applyNativeAppearance(theme)

        let baseURL = currentFileURL.deletingLastPathComponent()
        let payload: [String: Any] = [
            "markdown": markdown,
            "baseURL": baseURL.absoluteString,
            "rootURL": rootFolderURL.skimdownCanonicalFileURL.absoluteString.hasSuffix("/") ? rootFolderURL.skimdownCanonicalFileURL.absoluteString : rootFolderURL.skimdownCanonicalFileURL.absoluteString + "/",
            "theme": theme.rawValue,
            "fontSize": fontSize
        ]

        let html: String
        do {
            html = try Self.buildHTML(payload: payload, theme: theme, katexFontsURL: katexFontsURLString())
        } catch {
            loadFallbackErrorHTML(
                message: "Preview resources could not be loaded.\n\(error.localizedDescription)",
                theme: theme,
                fontSize: fontSize,
                baseURL: baseURL,
                generation: generation,
                completion: completion
            )
            return
        }

        guard preserveScrollPosition else {
            loadHTML(html, baseURL: baseURL, generation: generation, scrollY: nil, completion: completion)
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let value = try? await self.webView.evaluateJavaScript("window.scrollY")
            guard self.renderGeneration == generation else {
                return
            }
            self.loadHTML(html, baseURL: baseURL, generation: generation, scrollY: value as? Double, completion: completion)
        }
    }

    func showError(_ message: String, theme: AppTheme, fontSize: Double, completion: (() -> Void)? = nil) {
        let generation = advanceRenderGeneration()
        applyNativeAppearance(theme)
        let payload: [String: Any] = [
            "markdown": "> **Error**\\n>\\n> \(message)",
            "baseURL": Bundle.main.bundleURL.absoluteString,
            "rootURL": Bundle.main.bundleURL.absoluteString,
            "theme": theme.rawValue,
            "fontSize": fontSize
        ]
        do {
            loadHTML(
                try Self.buildHTML(payload: payload, theme: theme, katexFontsURL: katexFontsURLString()),
                baseURL: Bundle.main.bundleURL,
                generation: generation,
                scrollY: nil,
                completion: completion
            )
        } catch {
            loadFallbackErrorHTML(
                message: "\(message)\n\n\(error.localizedDescription)",
                theme: theme,
                fontSize: fontSize,
                baseURL: Bundle.main.bundleURL,
                generation: generation,
                completion: completion
            )
        }
    }

    func performSearch(query: String, caseSensitive: Bool, completion: @escaping (SearchResult) -> Void) {
        evaluateSearchScript("window.skimdown.performSearch(\(Self.jsonString(query)), \(caseSensitive ? "true" : "false"))", completion: completion)
    }

    func findNext(completion: @escaping (SearchResult) -> Void) {
        evaluateSearchScript("window.skimdown.nextSearch()", completion: completion)
    }

    func findPrevious(completion: @escaping (SearchResult) -> Void) {
        evaluateSearchScript("window.skimdown.previousSearch()", completion: completion)
    }

    func scrollToAnchor(_ anchor: String?) {
        let anchor = anchor ?? ""
        webView.evaluateJavaScript("window.skimdown.scrollToAnchor(\(Self.jsonString(anchor)))")
    }

    func copySelection() {
        webView.window?.makeFirstResponder(webView)
        NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: webView)
    }

    func selectAll() {
        webView.window?.makeFirstResponder(webView)
        NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: webView)
    }

    func selectedText(completion: @escaping (String) -> Void) {
        webView.evaluateJavaScript("window.getSelection().toString()") { value, _ in
            completion(value as? String ?? "")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "linkClick", let href = message.body as? String {
            delegate?.markdownWebView(self, didRequestLink: href)
        } else if message.name == "copyCode", let code = message.body as? String {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(code, forType: .string)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let navigation,
              let pendingNavigation,
              pendingNavigation.navigation === navigation,
              pendingNavigation.generation == renderGeneration else {
            return
        }

        self.pendingNavigation = nil
        if let scrollY = pendingNavigation.scrollY, scrollY > 0 {
            webView.evaluateJavaScript("window.scrollTo(0, \(scrollY))")
        }
        pendingNavigation.completion?()
    }

    private func evaluateSearchScript(_ script: String, completion: @escaping (SearchResult) -> Void) {
        webView.evaluateJavaScript(script) { value, _ in
            guard let dictionary = value as? [String: Any] else {
                completion(SearchResult(count: 0, index: 0))
                return
            }
            completion(SearchResult(count: dictionary["count"] as? Int ?? 0, index: dictionary["index"] as? Int ?? 0))
        }
    }

    private func applyNativeAppearance(_ theme: AppTheme) {
        switch theme {
        case .system:
            webView.appearance = nil
        case .light:
            webView.appearance = NSAppearance(named: .aqua)
        case .dark:
            webView.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func advanceRenderGeneration() -> Int {
        renderGeneration += 1
        pendingNavigation = nil
        return renderGeneration
    }

    private func loadHTML(_ html: String, baseURL: URL, generation: Int, scrollY: Double?, completion: (() -> Void)?) {
        guard renderGeneration == generation else {
            return
        }
        guard let navigation = webView.loadHTMLString(html, baseURL: baseURL) else {
            completion?()
            return
        }
        pendingNavigation = PendingNavigation(navigation: navigation, generation: generation, scrollY: scrollY, completion: completion)
    }

    private static func buildHTML(payload: [String: Any], theme: AppTheme, katexFontsURL: String) throws -> String {
        let css = [
            try readWebResource("vendor/katex/katex.min.css").replacingOccurrences(of: "url(fonts/", with: "url(\(katexFontsURL)/"),
            try readWebResource("vendor/highlight.js/github.min.css"),
            try readWebResource("vendor/highlight.js/github-dark.min.css"),
            try readWebResource("skimdown.css")
        ].joined(separator: "\n")

        let scripts = [
            try readWebResource("vendor/markdown-it/markdown-it.min.js"),
            try readWebResource("vendor/markdown-it-footnote/markdown-it-footnote.min.js"),
            try readWebResource("vendor/dompurify/purify.min.js"),
            try readWebResource("vendor/katex/katex.min.js"),
            try readWebResource("vendor/katex/auto-render.min.js"),
            try readWebResource("vendor/mermaid/mermaid.min.js"),
            try readWebResource("vendor/highlight.js/highlight.min.js"),
            try readWebResource("renderer.js")
        ].joined(separator: "\n")

        return """
        <!doctype html>
        <html data-theme="\(theme.rawValue)">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>\(css)</style>
          </head>
          <body>
            <main id="content"></main>
            <script>\(scripts)</script>
            <script>window.skimdown.render(\(Self.jsonObject(payload)));</script>
          </body>
        </html>
        """
    }

    private static func readWebResource(_ relativePath: String) throws -> String {
        if let cached = webResourceCache[relativePath] {
            return cached
        }

        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Web").appendingPathComponent(relativePath) else {
            throw WebResourceError.missing(relativePath)
        }

        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            webResourceCache[relativePath] = contents
            return contents
        } catch {
            throw WebResourceError.unreadable(relativePath, error)
        }
    }

    private func loadFallbackErrorHTML(
        message: String,
        theme: AppTheme,
        fontSize: Double,
        baseURL: URL,
        generation: Int,
        completion: (() -> Void)?
    ) {
        applyNativeAppearance(theme)

        let escapedMessage = Self.htmlEscaped(message)
            .replacingOccurrences(of: "\n", with: "<br>")
        let html = """
        <!doctype html>
        <html data-theme="\(theme.rawValue)">
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    body {
                        margin: 0;
                        padding: 32px;
                        color: #1f2937;
                        background: #ffffff;
                        font: \(fontSize)px -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
                        line-height: 1.6;
                    }
                    @media (prefers-color-scheme: dark) {
                        body { color: #f3f4f6; background: #111827; }
                    }
                    .error {
                        max-width: 760px;
                        border-left: 4px solid #dc2626;
                        padding-left: 16px;
                    }
                    h1 { margin: 0 0 12px; font-size: 1.2em; }
                    p { margin: 0; }
                </style>
            </head>
            <body>
                <section class="error">
                    <h1>Preview error</h1>
                    <p>\(escapedMessage)</p>
                </section>
            </body>
        </html>
        """

        loadHTML(html, baseURL: baseURL, generation: generation, scrollY: nil, completion: completion)
    }

    private func katexFontsURLString() -> String {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Web/vendor/katex/fonts") else {
            return ""
        }
        return url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func jsonObject(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string.replacingOccurrences(of: "</", with: "<\\/")
    }

    private static func jsonString(_ string: String) -> String {
        jsonObject([string]).dropFirst().dropLast().description
    }

    private static func htmlEscaped(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

@MainActor
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: (any WKScriptMessageHandler)?

    init(delegate: any WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
