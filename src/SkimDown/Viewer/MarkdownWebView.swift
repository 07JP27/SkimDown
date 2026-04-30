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
final class MarkdownWebView: NSView, WKScriptMessageHandler {
    weak var delegate: MarkdownWebViewDelegate?

    private let webView: WKWebView
    private var currentTheme: AppTheme = .system

    override init(frame frameRect: NSRect) {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        configuration.userContentController = userContentController
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frameRect)

        userContentController.add(WeakScriptMessageHandler(delegate: self), name: "linkClick")
        userContentController.add(WeakScriptMessageHandler(delegate: self), name: "copyCode")

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

    func render(markdown: String, currentFileURL: URL, rootFolderURL: URL, theme: AppTheme, fontSize: Double) {
        currentTheme = theme
        applyNativeAppearance(theme)

        let baseURL = currentFileURL.deletingLastPathComponent()
        let payload: [String: Any] = [
            "markdown": markdown,
            "baseURL": baseURL.absoluteString,
            "rootURL": rootFolderURL.skimdownCanonicalFileURL.absoluteString.hasSuffix("/") ? rootFolderURL.skimdownCanonicalFileURL.absoluteString : rootFolderURL.skimdownCanonicalFileURL.absoluteString + "/",
            "theme": theme.rawValue,
            "fontSize": fontSize
        ]

        webView.loadHTMLString(buildHTML(payload: payload), baseURL: baseURL)
    }

    func showError(_ message: String, theme: AppTheme, fontSize: Double) {
        currentTheme = theme
        applyNativeAppearance(theme)
        let payload: [String: Any] = [
            "markdown": "> **Error**\\n>\\n> \(message)",
            "baseURL": Bundle.main.bundleURL.absoluteString,
            "rootURL": Bundle.main.bundleURL.absoluteString,
            "theme": theme.rawValue,
            "fontSize": fontSize
        ]
        webView.loadHTMLString(buildHTML(payload: payload), baseURL: Bundle.main.bundleURL)
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

    private func buildHTML(payload: [String: Any]) -> String {
        let css = [
            readWebResource("vendor/katex/katex.min.css").replacingOccurrences(of: "url(fonts/", with: "url(\(katexFontsURLString())/"),
            readWebResource("vendor/highlight.js/github.min.css"),
            readWebResource("vendor/highlight.js/github-dark.min.css"),
            readWebResource("skimdown.css")
        ].joined(separator: "\n")

        let scripts = [
            readWebResource("vendor/markdown-it/markdown-it.min.js"),
            readWebResource("vendor/markdown-it-footnote/markdown-it-footnote.min.js"),
            readWebResource("vendor/dompurify/purify.min.js"),
            readWebResource("vendor/katex/katex.min.js"),
            readWebResource("vendor/katex/auto-render.min.js"),
            readWebResource("vendor/mermaid/mermaid.min.js"),
            readWebResource("vendor/highlight.js/highlight.min.js"),
            readWebResource("renderer.js")
        ].joined(separator: "\n")

        return """
        <!doctype html>
        <html data-theme="\(currentTheme.rawValue)">
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

    private func readWebResource(_ relativePath: String) -> String {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Web").appendingPathComponent(relativePath),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return contents
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
