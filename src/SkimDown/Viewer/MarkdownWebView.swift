import AppKit
import WebKit

struct SearchResult {
    let count: Int
    let index: Int
}

struct PreviewLayoutMetrics {
    let contentRight: Double
    let viewportWidth: Double
}

@MainActor
protocol MarkdownWebViewDelegate: AnyObject {
    func markdownWebView(_ webView: MarkdownWebView, didRequestLink href: String)
    func markdownWebViewDidChangeEffectiveAppearance(_ webView: MarkdownWebView)
    func markdownWebView(_ webView: MarkdownWebView, didChangeActiveHeadingID headingID: String?)
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

    private enum ScriptMessage: String, CaseIterable {
        case linkClick
        case copyCode
        case renderReady
        case userInteracted
        case scrollPosition
        case activeHeading
    }

    private struct PendingNavigation {
        let navigation: WKNavigation
        let generation: Int
        let scrollY: Double?
        let completion: (() -> Void)?
        let waitsForRenderReady: Bool
        var didFinishNavigation: Bool
        var didRenderContent: Bool

        var isReady: Bool {
            didFinishNavigation && didRenderContent
        }

        mutating func markNavigationFinished() {
            didFinishNavigation = true
            if !waitsForRenderReady {
                didRenderContent = true
            }
        }

        mutating func markRenderReady() {
            didRenderContent = true
        }
    }

    private let webView: WKWebView
    private let localFileSchemeHandler = LocalFileSchemeHandler()
    private var renderGeneration = 0
    private var pendingNavigation: PendingNavigation?
    private var observedScrollY: Double?
    private var reservedTrailingWidth: Double = 0

    override init(frame frameRect: NSRect) {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        configuration.userContentController = userContentController
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.setURLSchemeHandler(localFileSchemeHandler, forURLScheme: LocalFileSchemeHandler.scheme)

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frameRect)

        for scriptMessage in ScriptMessage.allCases {
            userContentController.add(WeakScriptMessageHandler(delegate: self), name: scriptMessage.rawValue)
        }

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
        for scriptMessage in ScriptMessage.allCases {
            userContentController.removeScriptMessageHandler(forName: scriptMessage.rawValue)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        delegate?.markdownWebViewDidChangeEffectiveAppearance(self)
    }

    func render(
        markdown: String,
        currentFileURL: URL,
        rootFolderURL: URL,
        theme: AppTheme,
        resolvedTheme: ResolvedTheme?,
        fontSize: Double,
        preserveScrollPosition: Bool = false,
        restoreScrollY: Double? = nil,
        completion: (() -> Void)? = nil
    ) {
        let generation = advanceRenderGeneration()
        applyNativeAppearance(theme, resolvedTheme: resolvedTheme)
        localFileSchemeHandler.rootFolderURL = rootFolderURL

        let baseURL = currentFileURL.deletingLastPathComponent()

        let buildAndLoad: (Double) -> Void = { [weak self] effectiveScrollY in
            guard let self else { return }
            guard self.renderGeneration == generation else { return }
            let payload = Self.renderPayload(
                markdown: markdown,
                baseURL: baseURL,
                rootURL: rootFolderURL,
                theme: theme,
                resolvedTheme: resolvedTheme,
                fontSize: fontSize,
                generation: generation,
                restoreScrollY: effectiveScrollY,
                reservedTrailingWidth: reservedTrailingWidth
            )
            do {
                let html = try Self.buildHTML(payload: payload, theme: theme, resolvedTheme: resolvedTheme, katexFontsURL: self.katexFontsURLString())
                self.loadHTML(html, baseURL: baseURL, generation: generation, scrollY: effectiveScrollY > 0 ? effectiveScrollY : nil, completion: completion)
            } catch {
                self.loadFallbackErrorHTML(
                    message: "Preview resources could not be loaded.\n\(error.localizedDescription)",
                    theme: theme,
                    resolvedTheme: resolvedTheme,
                    fontSize: fontSize,
                    baseURL: baseURL,
                    generation: generation,
                    completion: completion
                )
            }
        }

        if let restoreScrollY {
            buildAndLoad(restoreScrollY > 0 ? restoreScrollY : 0)
            return
        }

        guard preserveScrollPosition else {
            buildAndLoad(0)
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let value = try? await self.webView.evaluateJavaScript("window.scrollY")
            guard self.renderGeneration == generation else { return }
            let captured = Self.doubleValue(value) ?? 0
            buildAndLoad(captured > 0 ? captured : 0)
        }
    }

    var currentObservedScrollY: Double? {
        observedScrollY
    }

    func setReservedTrailingWidth(_ width: Double) {
        let normalizedWidth = max(0, width)
        reservedTrailingWidth = normalizedWidth
        webView.evaluateJavaScript("window.skimdown && window.skimdown.setReservedTrailingWidth(\(normalizedWidth))")
    }

    func showError(_ message: String, theme: AppTheme, resolvedTheme: ResolvedTheme?, fontSize: Double, completion: (() -> Void)? = nil) {
        let generation = advanceRenderGeneration()
        applyNativeAppearance(theme, resolvedTheme: resolvedTheme)
        let payload = Self.renderPayload(
            markdown: "> **Error**\\n>\\n> \(message)",
            baseURL: Bundle.main.bundleURL,
            rootURL: Bundle.main.bundleURL,
            theme: theme,
            resolvedTheme: resolvedTheme,
            fontSize: fontSize,
            generation: generation,
            restoreScrollY: 0,
            reservedTrailingWidth: reservedTrailingWidth
        )
        do {
            loadHTML(
                try Self.buildHTML(payload: payload, theme: theme, resolvedTheme: resolvedTheme, katexFontsURL: katexFontsURLString()),
                baseURL: Bundle.main.bundleURL,
                generation: generation,
                scrollY: nil,
                completion: completion
            )
        } catch {
            loadFallbackErrorHTML(
                message: "\(message)\n\n\(error.localizedDescription)",
                theme: theme,
                resolvedTheme: resolvedTheme,
                fontSize: fontSize,
                baseURL: Bundle.main.bundleURL,
                generation: generation,
                completion: completion
            )
        }
    }

    func performSearch(query: String, caseSensitive: Bool, scrollToMatch: Bool = true, completion: @escaping (SearchResult) -> Void) {
        evaluateSearchScript(
            "window.skimdown.performSearch(\(Self.jsonString(query)), \(caseSensitive ? "true" : "false"), \(scrollToMatch ? "true" : "false"))",
            completion: completion
        )
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

    func scrollToElementID(_ elementID: String) {
        webView.evaluateJavaScript("window.skimdown.scrollToElementID(\(Self.jsonString(elementID)))")
    }

    func tableOfContents(completion: @escaping ([TableOfContentsItem]) -> Void) {
        webView.evaluateJavaScript("window.skimdown.tableOfContents()") { value, _ in
            guard let rows = value as? [[String: Any]] else {
                completion([])
                return
            }
            completion(rows.compactMap(TableOfContentsItem.init(javaScriptDictionary:)))
        }
    }

    func previewLayoutMetrics(completion: @escaping (PreviewLayoutMetrics?) -> Void) {
        webView.evaluateJavaScript("window.skimdown && window.skimdown.previewLayoutMetrics && window.skimdown.previewLayoutMetrics()") { value, _ in
            guard let dictionary = value as? [String: Any],
                  let contentRight = Self.doubleValue(dictionary["contentRight"]),
                  let viewportWidth = Self.doubleValue(dictionary["viewportWidth"]) else {
                completion(nil)
                return
            }
            completion(PreviewLayoutMetrics(contentRight: contentRight, viewportWidth: viewportWidth))
        }
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
        guard let scriptMessage = ScriptMessage(rawValue: message.name) else {
            return
        }

        switch scriptMessage {
        case .linkClick:
            guard let href = message.body as? String else {
                return
            }
            delegate?.markdownWebView(self, didRequestLink: href)
        case .copyCode:
            guard let code = message.body as? String else {
                return
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(code, forType: .string)
        case .renderReady:
            guard let body = message.body as? [String: Any],
                  let renderID = Self.intValue(body["renderID"]) else {
                return
            }
            markRenderReady(generation: renderID)
        case .userInteracted:
            guard let body = message.body as? [String: Any],
                  let renderID = Self.intValue(body["renderID"]),
                  renderID == renderGeneration else {
                return
            }
            cancelPendingScrollRestoration()
        case .scrollPosition:
            guard let body = message.body as? [String: Any],
                  let renderID = Self.intValue(body["renderID"]),
                  renderID == renderGeneration,
                  let value = Self.doubleValue(body["scrollY"]) else {
                return
            }
            observedScrollY = value
        case .activeHeading:
            guard let body = message.body as? [String: Any],
                  let renderID = Self.intValue(body["renderID"]),
                  renderID == renderGeneration else {
                return
            }
            let headingID = (body["headingID"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            delegate?.markdownWebView(self, didChangeActiveHeadingID: headingID)
        }
    }

    private func cancelPendingScrollRestoration() {
        guard var pendingNavigation, pendingNavigation.scrollY != nil else {
            return
        }
        pendingNavigation = PendingNavigation(
            navigation: pendingNavigation.navigation,
            generation: pendingNavigation.generation,
            scrollY: nil,
            completion: pendingNavigation.completion,
            waitsForRenderReady: pendingNavigation.waitsForRenderReady,
            didFinishNavigation: pendingNavigation.didFinishNavigation,
            didRenderContent: pendingNavigation.didRenderContent
        )
        self.pendingNavigation = pendingNavigation
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let navigation,
              var pendingNavigation,
              pendingNavigation.navigation === navigation,
              pendingNavigation.generation == renderGeneration else {
            return
        }

        pendingNavigation.markNavigationFinished()
        self.pendingNavigation = pendingNavigation
        finishPendingNavigationIfReady()
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

    private func applyNativeAppearance(_ theme: AppTheme, resolvedTheme: ResolvedTheme?) {
        switch theme {
        case .system:
            webView.appearance = nil
        case .light:
            webView.appearance = NSAppearance(named: .aqua)
        case .dark:
            webView.appearance = NSAppearance(named: .darkAqua)
        case .custom:
            // Treat unresolved custom themes as System while the store is reloading or the theme is missing.
            if let resolvedTheme {
                webView.appearance = NSAppearance(named: resolvedTheme.isDark ? .darkAqua : .aqua)
            } else {
                webView.appearance = nil
            }
        }
    }

    private func advanceRenderGeneration() -> Int {
        renderGeneration += 1
        pendingNavigation = nil
        return renderGeneration
    }

    private func loadHTML(
        _ html: String,
        baseURL: URL,
        generation: Int,
        scrollY: Double?,
        waitsForRenderReady: Bool = true,
        completion: (() -> Void)?
    ) {
        guard renderGeneration == generation else {
            return
        }
        observedScrollY = nil
        guard let navigation = webView.loadHTMLString(html, baseURL: baseURL) else {
            completion?()
            return
        }
        pendingNavigation = PendingNavigation(
            navigation: navigation,
            generation: generation,
            scrollY: scrollY,
            completion: completion,
            waitsForRenderReady: waitsForRenderReady,
            didFinishNavigation: false,
            didRenderContent: false
        )
    }

    private func markRenderReady(generation: Int) {
        guard var pendingNavigation,
              pendingNavigation.generation == generation,
              generation == renderGeneration else {
            return
        }
        pendingNavigation.markRenderReady()
        self.pendingNavigation = pendingNavigation
        finishPendingNavigationIfReady()
    }

    private func finishPendingNavigationIfReady() {
        guard let pendingNavigation,
              pendingNavigation.generation == renderGeneration,
              pendingNavigation.isReady else {
            return
        }

        self.pendingNavigation = nil
        let completion = pendingNavigation.completion
        if observedScrollY == nil {
            observedScrollY = pendingNavigation.scrollY ?? 0
        }
        completion?()
    }

    private static func buildHTML(payload: [String: Any], theme: AppTheme, resolvedTheme: ResolvedTheme?, katexFontsURL: String) throws -> String {
        let highlightCSSPath = highlightCSSResourcePath(for: theme, resolvedTheme: resolvedTheme)
        let css = [
            try readWebResource("vendor/katex/katex.min.css").replacingOccurrences(of: "url(fonts/", with: "url(\(katexFontsURL)/"),
            try readWebResource(highlightCSSPath),
            try readWebResource("skimdown.css")
        ].joined(separator: "\n")

        let scripts = [
            try readWebResource("vendor/markdown-it/markdown-it.min.js"),
            try readWebResource("vendor/markdown-it-footnote/markdown-it-footnote.min.js"),
            try readWebResource("vendor/markdown-it-imsize/markdown-it-imsize.min.js"),
            try readWebResource("vendor/markdown-it-emoji/markdown-it-emoji.min.js"),
            try readWebResource("vendor/dompurify/purify.min.js"),
            try readWebResource("vendor/katex/katex.min.js"),
            try readWebResource("vendor/katex/auto-render.min.js"),
            try readWebResource("vendor/mermaid/mermaid.min.js"),
            try readWebResource("vendor/highlight.js/highlight.min.js"),
            try readWebResource("renderer.js")
        ].joined(separator: "\n")

        let dataTheme = Self.dataThemeAttribute(for: theme)
        let dataThemeType = Self.dataThemeTypeAttribute(for: theme, resolvedTheme: resolvedTheme)
        let customStyle = Self.customThemeStyleBlock(resolvedTheme: resolvedTheme)

        return """
        <!doctype html>
        <html data-theme="\(dataTheme)" data-theme-type="\(dataThemeType)">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>\(css)</style>
            \(customStyle)
          </head>
          <body>
            <main id="content"></main>
            <script>\(scripts)</script>
            <script>window.skimdown.render(\(Self.jsonObject(payload)));</script>
          </body>
        </html>
        """
    }

    /// Value for `<html data-theme="...">`.
    /// Built-in themes keep their name; custom themes use "custom".
    private static func dataThemeAttribute(for theme: AppTheme) -> String {
        switch theme {
        case .system: return "system"
        case .light: return "light"
        case .dark: return "dark"
        case .custom: return "custom"
        }
    }

    /// Value for `<html data-theme-type="...">` ("light" / "dark").
    /// System resolves to the current effective appearance, and custom themes use their resolved type.
    private static func dataThemeTypeAttribute(for theme: AppTheme, resolvedTheme: ResolvedTheme?) -> String {
        isEffectiveThemeDark(theme, resolvedTheme: resolvedTheme) ? "dark" : "light"
    }

    static func highlightCSSResourcePath(for theme: AppTheme, resolvedTheme: ResolvedTheme?) -> String {
        isEffectiveThemeDark(theme, resolvedTheme: resolvedTheme)
            ? "vendor/highlight.js/github-dark.min.css"
            : "vendor/highlight.js/github.min.css"
    }

    static func isEffectiveThemeDark(_ theme: AppTheme, resolvedTheme: ResolvedTheme?) -> Bool {
        switch theme {
        case .system:
            return isSystemAppearanceDark()
        case .light:
            return false
        case .dark:
            return true
        case .custom:
            return resolvedTheme?.isDark ?? isSystemAppearanceDark()
        }
    }

    private static func isSystemAppearanceDark() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    nonisolated static let customThemeCSSSelector = #":root[data-theme="custom"][data-theme-type]"#

    /// Returns CSS variable overrides for a custom theme. Built-in themes return an empty string.
    private static func customThemeStyleBlock(resolvedTheme: ResolvedTheme?) -> String {
        guard let resolvedTheme else { return "" }
        let declarations = resolvedTheme.cssVariables
            .map { "  \($0.name): \($0.value);" }
            .joined(separator: "\n")
        return """
        <style>
        \(customThemeCSSSelector) {
        \(declarations)
        }
        </style>
        """
    }

    private static func renderPayload(
        markdown: String,
        baseURL: URL,
        rootURL: URL,
        theme: AppTheme,
        resolvedTheme: ResolvedTheme?,
        fontSize: Double,
        generation: Int,
        restoreScrollY: Double,
        reservedTrailingWidth: Double
    ) -> [String: Any] {
        let themeIsDark = isEffectiveThemeDark(theme, resolvedTheme: resolvedTheme)
        return [
            "markdown": markdown,
            "baseURL": baseURL.absoluteString,
            "rootURL": directoryURLString(for: rootURL),
            "localFileScheme": LocalFileSchemeHandler.scheme,
            "theme": dataThemeAttribute(for: theme),
            "themeIsDark": themeIsDark,
            "fontSize": fontSize,
            "renderID": generation,
            "restoreScrollY": restoreScrollY,
            "reservedTrailingWidth": reservedTrailingWidth
        ]
    }

    private static func directoryURLString(for url: URL) -> String {
        let absoluteString = url.skimdownCanonicalFileURL.absoluteString
        return absoluteString.hasSuffix("/") ? absoluteString : absoluteString + "/"
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
        resolvedTheme: ResolvedTheme?,
        fontSize: Double,
        baseURL: URL,
        generation: Int,
        completion: (() -> Void)?
    ) {
        applyNativeAppearance(theme, resolvedTheme: resolvedTheme)

        let escapedMessage = Self.htmlEscaped(message)
            .replacingOccurrences(of: "\n", with: "<br>")
        let dataTheme = Self.dataThemeAttribute(for: theme)
        let dataThemeType = Self.dataThemeTypeAttribute(for: theme, resolvedTheme: resolvedTheme)
        let html = """
        <!doctype html>
        <html data-theme="\(dataTheme)" data-theme-type="\(dataThemeType)">
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
                    :root[data-theme-type="dark"] body {
                        color: #f3f4f6;
                        background: #111827;
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

        loadHTML(html, baseURL: baseURL, generation: generation, scrollY: nil, waitsForRenderReady: false, completion: completion)
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

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return nil
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
