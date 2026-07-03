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
    func testCodeCopyButtonShowsFeedbackAndResetsTimer() async throws {
        let copyMessageExpectation = expectation(description: "copyCode messages")
        copyMessageExpectation.expectedFulfillmentCount = 2
        let copyRecorder = ScriptMessageRecorder {
            copyMessageExpectation.fulfill()
        }
        let webView = try await renderMarkdown(
            """
            ```swift
            let answer = 42
            ```
            """,
            copyCodeMessageHandler: copyRecorder
        )

        let resultJSON = try await evaluateStringJavaScript(
            """
            (function () {
              var nativeSetTimeout = window.setTimeout;
              var nativeClearTimeout = window.clearTimeout;
              var timers = [];
              window.setTimeout = function (callback, delay) {
                var id = timers.length + 1;
                timers.push({ id: id, callback: callback, delay: delay, cleared: false });
                return id;
              };
              window.clearTimeout = function (id) {
                var timer = timers.find(function (timer) { return timer.id === id; });
                if (timer) { timer.cleared = true; }
              };

              var button = document.querySelector(".code-copy");
              function buttonState() {
                return {
                  text: button.textContent,
                  ariaLabel: button.getAttribute("aria-label"),
                  hasCopiedClass: button.classList.contains("code-copy-copied")
                };
              }
              function fireTimer(timer) {
                if (timer && !timer.cleared) {
                  timer.cleared = true;
                  timer.callback();
                }
              }

              var initial = buttonState();
              button.click();
              var firstClick = buttonState();
              var firstTimer = timers[0];
              button.click();
              var secondClick = buttonState();
              var secondTimer = timers[1];
              var firstTimerCleared = firstTimer ? firstTimer.cleared : false;
              fireTimer(firstTimer);
              var afterFirstTimer = buttonState();
              fireTimer(secondTimer);
              var afterSecondTimer = buttonState();

              window.setTimeout = nativeSetTimeout;
              window.clearTimeout = nativeClearTimeout;

              return JSON.stringify({
                initial: initial,
                firstClick: firstClick,
                secondClick: secondClick,
                afterFirstTimer: afterFirstTimer,
                afterSecondTimer: afterSecondTimer,
                timerCount: timers.length,
                firstTimerDelay: firstTimer ? firstTimer.delay : -1,
                secondTimerDelay: secondTimer ? secondTimer.delay : -1,
                firstTimerCleared: firstTimerCleared
              });
            })();
            """,
            in: webView
        )
        await fulfillment(of: [copyMessageExpectation], timeout: 2)
        let result = try JSONDecoder().decode(CodeCopyFeedbackResult.self, from: Data(resultJSON.utf8))

        XCTAssertEqual(result.initial.text, "Copy")
        XCTAssertEqual(result.initial.ariaLabel, "Copy code")
        XCTAssertFalse(result.initial.hasCopiedClass)

        XCTAssertEqual(result.firstClick.text, "Copied")
        XCTAssertEqual(result.firstClick.ariaLabel, "Copied code")
        XCTAssertTrue(result.firstClick.hasCopiedClass)
        XCTAssertGreaterThan(result.firstTimerDelay, 0)

        XCTAssertEqual(result.secondClick.text, "Copied")
        XCTAssertEqual(result.secondClick.ariaLabel, "Copied code")
        XCTAssertTrue(result.secondClick.hasCopiedClass)
        XCTAssertEqual(result.timerCount, 2)
        XCTAssertGreaterThan(result.secondTimerDelay, 0)
        XCTAssertTrue(result.firstTimerCleared)

        XCTAssertEqual(result.afterFirstTimer.text, "Copied")
        XCTAssertEqual(result.afterFirstTimer.ariaLabel, "Copied code")
        XCTAssertTrue(result.afterFirstTimer.hasCopiedClass)

        XCTAssertEqual(result.afterSecondTimer.text, "Copy")
        XCTAssertEqual(result.afterSecondTimer.ariaLabel, "Copy code")
        XCTAssertFalse(result.afterSecondTimer.hasCopiedClass)
        XCTAssertEqual(copyRecorder.messages, ["let answer = 42\n", "let answer = 42\n"])
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
    func testMermaidExpandPaneOpensZoomsAndCloses() async throws {
        let webView = try await renderMarkdown(
            """
            ```mermaid
            graph LR
                A[Start] --> B[Middle] --> C[End]
            ```
            """,
            additionalScripts: [Self.mermaidStubScript],
            additionalStyles: [Self.mermaidModalTestStyle]
        )
        try await waitForJavaScriptCondition(
            "document.querySelector('.mermaid-expand:not([disabled])') !== null",
            in: webView
        )

        try await evaluateStringJavaScript(
            """
            (function () {
              var expand = document.querySelector('.mermaid-expand');
              document.body.tabIndex = -1;
              document.body.focus();
              expand.click();
              return "opened";
            })();
            """,
            in: webView
        )
        try await waitForJavaScriptCondition(
            "document.querySelector('.mermaid-modal-viewport') && document.querySelector('.mermaid-modal-viewport').dataset.zoomBaseline",
            in: webView
        )

        let resultJSON = try await evaluateStringJavaScript(
            """
            (function () {
              var expand = document.querySelector('.mermaid-expand');
              var modal = document.querySelector('.mermaid-modal');
              var viewport = modal.querySelector('.mermaid-modal-viewport');
              var frame = modal.querySelector('.mermaid-modal-frame');
              var modalSVG = modal.querySelector('svg');
              var originalMarkerID = document.querySelector('.mermaid-container svg marker').id;
              var modalMarkerID = modalSVG.querySelector('marker').id;
              var modalMarkerEnd = modalSVG.querySelector('path[marker-end]').getAttribute('marker-end');
              var bodyLockedAfterOpen = document.body.classList.contains('skimdown-mermaid-modal-open');
              var htmlLockedAfterOpen = document.documentElement.classList.contains('skimdown-mermaid-modal-open');
              var baselineZoom = Number(viewport.dataset.zoomBaseline);
              var initialZoom = Number(viewport.dataset.zoom);
              var firstControl = modal.querySelector('.mermaid-modal-zoom-out');
              var lastControl = modal.querySelector('.mermaid-modal-close');
              modal.focus();
              modal.dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true }));
              var tabFromModalFocusesFirstControl = document.activeElement === firstControl;
              modal.focus();
              modal.dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', shiftKey: true, bubbles: true, cancelable: true }));
              var shiftTabFromModalFocusesLastControl = document.activeElement === lastControl;

              modal.querySelector('.mermaid-modal-zoom-in').click();
              var zoomAfterZoomIn = Number(viewport.dataset.zoom);
              var transformAfterZoom = viewport.style.transform;

              frame.style.flex = '0 0 auto';
              frame.style.width = '600px';
              frame.style.height = '300px';
              window.dispatchEvent(new Event('resize'));
              var zoomAfterResizeEvent = Number(viewport.dataset.zoom);
              var baselineAfterResizeEvent = Number(viewport.dataset.zoomBaseline);
              modal.querySelector('.mermaid-modal-zoom-reset').click();
              var zoomAfterReset = Number(viewport.dataset.zoom);
              var baselineAfterResizeReset = Number(viewport.dataset.zoomBaseline);
              var panXAfterReset = viewport.dataset.panX;
              var panYAfterReset = viewport.dataset.panY;
              var transformAfterReset = viewport.style.transform;
              viewport.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, button: 0 }));
              modal.dispatchEvent(new MouseEvent('click', { bubbles: true }));
              var stayedOpenAfterDragReleaseOnBackdrop = document.querySelector('.mermaid-modal') !== null;

              var openerFocusAttemptedAfterHidden = false;
              var originalExpandFocus = expand.focus.bind(expand);
              expand.focus = function () {
                openerFocusAttemptedAfterHidden = true;
                originalExpandFocus();
              };
              expand.style.visibility = 'hidden';
              modal.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));

              return JSON.stringify({
                modalOpened: modal !== null,
                bodyLockedAfterOpen: bodyLockedAfterOpen,
                htmlLockedAfterOpen: htmlLockedAfterOpen,
                modalSVGWidthAttribute: modalSVG.getAttribute('width'),
                modalSVGHeightAttribute: modalSVG.getAttribute('height'),
                modalSVGStyleWidth: modalSVG.style.width,
                modalSVGStyleHeight: modalSVG.style.height,
                modalSVGStyleMaxWidth: modalSVG.style.maxWidth,
                baselineZoom: baselineZoom,
                initialZoom: initialZoom,
                tabFromModalFocusesFirstControl: tabFromModalFocusesFirstControl,
                shiftTabFromModalFocusesLastControl: shiftTabFromModalFocusesLastControl,
                zoomAfterZoomIn: zoomAfterZoomIn,
                zoomAfterResizeEvent: zoomAfterResizeEvent,
                baselineAfterResizeEvent: baselineAfterResizeEvent,
                zoomAfterReset: zoomAfterReset,
                baselineAfterResizeReset: baselineAfterResizeReset,
                panXAfterReset: panXAfterReset,
                panYAfterReset: panYAfterReset,
                transformAfterZoom: transformAfterZoom,
                transformAfterReset: transformAfterReset,
                stayedOpenAfterDragReleaseOnBackdrop: stayedOpenAfterDragReleaseOnBackdrop,
                modalExistsAfterClose: document.querySelector('.mermaid-modal') !== null,
                bodyLockedAfterClose: document.body.classList.contains('skimdown-mermaid-modal-open'),
                htmlLockedAfterClose: document.documentElement.classList.contains('skimdown-mermaid-modal-open'),
                openerFocusAttemptedAfterHidden: openerFocusAttemptedAfterHidden,
                focusRestoredToContainer: document.activeElement === document.querySelector('.mermaid-container'),
                originalMarkerID: originalMarkerID,
                modalMarkerID: modalMarkerID,
                modalMarkerEnd: modalMarkerEnd
              });
            })();
            """,
            in: webView
        )
        let result = try JSONDecoder().decode(MermaidExpandPaneResult.self, from: Data(resultJSON.utf8))

        XCTAssertTrue(result.modalOpened)
        XCTAssertTrue(result.bodyLockedAfterOpen)
        XCTAssertTrue(result.htmlLockedAfterOpen)
        XCTAssertEqual(result.modalSVGWidthAttribute, "1200")
        XCTAssertEqual(result.modalSVGHeightAttribute, "240")
        XCTAssertEqual(result.modalSVGStyleWidth, "1200px")
        XCTAssertEqual(result.modalSVGStyleHeight, "240px")
        XCTAssertEqual(result.modalSVGStyleMaxWidth, "none")
        XCTAssertLessThan(result.baselineZoom, 1)
        XCTAssertEqual(result.initialZoom, result.baselineZoom, accuracy: 0.001)
        XCTAssertTrue(result.tabFromModalFocusesFirstControl)
        XCTAssertTrue(result.shiftTabFromModalFocusesLastControl)
        XCTAssertGreaterThan(result.zoomAfterZoomIn, result.baselineZoom)
        XCTAssertTrue(result.transformAfterZoom.contains("scale("))
        XCTAssertEqual(result.zoomAfterResizeEvent, result.zoomAfterZoomIn, accuracy: 0.001)
        XCTAssertEqual(result.baselineAfterResizeEvent, result.baselineZoom, accuracy: 0.001)
        XCTAssertLessThan(result.baselineAfterResizeReset, result.baselineZoom)
        XCTAssertEqual(result.baselineAfterResizeReset, 0.5, accuracy: 0.001)
        XCTAssertEqual(result.zoomAfterReset, result.baselineAfterResizeReset, accuracy: 0.001)
        XCTAssertEqual(result.panXAfterReset, "0")
        XCTAssertEqual(result.panYAfterReset, "0")
        if result.baselineAfterResizeReset == 1 {
            XCTAssertEqual(result.transformAfterReset, "")
        } else {
            XCTAssertTrue(result.transformAfterReset.contains("scale(\(result.baselineAfterResizeReset))"))
        }
        XCTAssertTrue(result.stayedOpenAfterDragReleaseOnBackdrop)
        XCTAssertFalse(result.modalExistsAfterClose)
        XCTAssertFalse(result.bodyLockedAfterClose)
        XCTAssertFalse(result.htmlLockedAfterClose)
        XCTAssertFalse(result.openerFocusAttemptedAfterHidden)
        XCTAssertTrue(result.focusRestoredToContainer)
        XCTAssertNotEqual(result.originalMarkerID, result.modalMarkerID)
        XCTAssertEqual(result.modalMarkerEnd, "url(#\(result.modalMarkerID))")
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
    func testRendererExposesTableOfContentsWithActualHeadingIDs() async throws {
        let webView = try await renderMarkdown(
            """
            <h2 id="custom-id">Custom Heading</h2>

            ## Content
            ## テスト
            ## External Links
            ## External Links
            """
        )

        let entriesJSON = try await evaluateStringJavaScript(
            "JSON.stringify(window.skimdown.tableOfContents())",
            in: webView
        )
        let entries = try JSONDecoder().decode([TableOfContentsEntryResult].self, from: Data(entriesJSON.utf8))

        XCTAssertEqual(entries, [
            TableOfContentsEntryResult(level: 2, title: "Custom Heading", id: "custom-id"),
            TableOfContentsEntryResult(level: 2, title: "Content", id: "content-1"),
            TableOfContentsEntryResult(level: 2, title: "テスト", id: "テスト"),
            TableOfContentsEntryResult(level: 2, title: "External Links", id: "external-links"),
            TableOfContentsEntryResult(level: 2, title: "External Links", id: "external-links-1")
        ])
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
    func testScrollToElementIDUsesExactDOMIDForTableOfContentsSelection() async throws {
        let webView = try await renderMarkdown(
            """
            <h2 id="foo%20bar">Encoded-looking ID</h2>
            """
        )

        let target = try await evaluateStringJavaScript(
            """
            window.__skimdownScrolledTo = null;
            document.getElementById('foo%20bar').scrollIntoView = function () { window.__skimdownScrolledTo = this.id; };
            window.skimdown.scrollToElementID('foo%20bar');
            window.__skimdownScrolledTo;
            """,
            in: webView
        )

        XCTAssertEqual(target, "foo%20bar")
    }

    @MainActor
    func testScrollToElementIDKeepsClickedHeadingActiveWhenItCannotReachAnchorBand() async throws {
        let activeHeadingRecorder = ActiveHeadingMessageRecorder()
        let webView = try await renderMarkdown(
            """
            ## Previous

            Paragraph.

            Paragraph.

            Paragraph.

            Paragraph.

            Paragraph.

            Paragraph.

            Paragraph.

            Paragraph.

            Paragraph.

            Paragraph.

            Paragraph.

            Paragraph.

            ## Target

            Short section.
            """,
            activeHeadingMessageHandler: activeHeadingRecorder
        )
        activeHeadingRecorder.removeAll()

        _ = try await evaluateStringJavaScript(
            """
            window.scrollTo(0, 0);
            document.getElementById('target').scrollIntoView = function () {};
            window.skimdown.scrollToElementID('target');
            window.dispatchEvent(new Event('scroll'));
            'done';
            """,
            in: webView
        )
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(activeHeadingRecorder.messages.last?.headingID, "target")
    }

    @MainActor
    func testSearchScrollClearsProgrammaticActiveHeadingOverride() async throws {
        let activeHeadingRecorder = ActiveHeadingMessageRecorder()
        let spacer = Array(repeating: "Paragraph.", count: 80).joined(separator: "\n\n")
        let webView = try await renderMarkdown(
            """
            ## Previous

            Search hit.

            \(spacer)

            ## Target

            Short section.
            """,
            activeHeadingMessageHandler: activeHeadingRecorder
        )
        activeHeadingRecorder.removeAll()

        _ = try await evaluateStringJavaScript(
            """
            window.scrollTo(0, 0);
            var originalScrollIntoView = Element.prototype.scrollIntoView;
            Element.prototype.scrollIntoView = function () {};
            window.skimdown.scrollToElementID('target');
            window.skimdown.performSearch('Search hit', false, true);
            Element.prototype.scrollIntoView = originalScrollIntoView;
            window.dispatchEvent(new Event('scroll'));
            'done';
            """,
            in: webView
        )
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(activeHeadingRecorder.messages.last?.headingID, "previous")
    }

    @MainActor
    func testRendererHandlesEmptyQueryStringInImageSource() async throws {
        let webView = try await renderMarkdown("![Image](assets/photo.png?)")
        let src = try await evaluateStringJavaScript(
            "document.querySelector('img').getAttribute('src')",
            in: webView
        )

        print("🔍 [STEP1] input: ![Image](assets/photo.png?)")
        print("🔍 [STEP1] img src = \(src)")
        print("🔍 [STEP1] contains '?&' = \(src.contains("?&"))")

        XCTAssertTrue(src.hasPrefix("\(LocalFileSchemeHandler.scheme)://"),
                       "Rewritten URL must use the local file scheme")
        XCTAssertFalse(src.contains("?&"),
                        "URL must not contain malformed '?&' sequence")

        let components = URLComponents(string: src)
        let queryItems = components?.queryItems ?? []
        XCTAssertEqual(queryItems.first(where: { $0.name == "__skimdown_render" })?.value, "1",
                        "Cache-busting render token must be present")
    }

    @MainActor
    func testRendererAddsRenderTokenToLocalImageSources() async throws {
        let webView = try await renderMarkdown("![Image](assets/photo.png?size=large)")
        let src = try await evaluateStringJavaScript(
            "document.querySelector('img').getAttribute('src')",
            in: webView
        )

        print("🔍 [STEP2] input: ![Image](assets/photo.png?size=large)")
        print("🔍 [STEP2] img src = \(src)")

        XCTAssertTrue(src.hasPrefix("\(LocalFileSchemeHandler.scheme)://"))

        let components = URLComponents(string: src)
        let queryItems = components?.queryItems ?? []
        let sizeVal = queryItems.first(where: { $0.name == "size" })?.value ?? "MISSING"
        let renderVal = queryItems.first(where: { $0.name == "__skimdown_render" })?.value ?? "MISSING"
        print("🔍 [STEP2] size param = \(sizeVal)")
        print("🔍 [STEP2] __skimdown_render = \(renderVal)")

        XCTAssertEqual(sizeVal, "large")
        XCTAssertEqual(renderVal, "1")
    }

    @MainActor
    func testRendererUpdatesRenderTokenAcrossRenders() async throws {
        let webView = try await renderMarkdown("![Image](assets/photo.png)")
        let resultJSON = try await evaluateStringJavaScript(
            """
            var first = new URL(document.querySelector('img').getAttribute('src')).searchParams.get('__skimdown_render');
            window.skimdown.render({
              markdown: '![Image](assets/photo.png)',
              baseURL: document.baseURI,
              rootURL: document.baseURI,
              localFileScheme: '\(LocalFileSchemeHandler.scheme)',
              theme: 'system',
              fontSize: 16,
              renderID: 2,
              restoreScrollY: 0
            });
            var second = new URL(document.querySelector('img').getAttribute('src')).searchParams.get('__skimdown_render');
            JSON.stringify({ first: first, second: second });
            """,
            in: webView
        )
        let result = try JSONDecoder().decode(RenderTokenResult.self, from: Data(resultJSON.utf8))

        print("🔍 [STEP3] input: ![Image](assets/photo.png) rendered twice")
        print("🔍 [STEP3] 1st render token = \(result.first ?? "nil")")
        print("🔍 [STEP3] 2nd render token = \(result.second ?? "nil")")
        print("🔍 [STEP3] token changed = \(result.first != result.second)")

        XCTAssertEqual(result.first, "1")
        XCTAssertEqual(result.second, "2")
    }

    @MainActor
    func testContentUsesExpandedPreviewWidth() async throws {
        let webView = try await renderMarkdown(
            """
            # Wide preview

            Paragraph content should use more than the old fixed 980px preview cap.
            """,
            frameWidth: 1400,
            includeStyles: true
        )

        let result = try await previewLayoutResult(in: webView)

        XCTAssertGreaterThan(result.contentWidth, 980)
        XCTAssertLessThanOrEqual(abs(result.contentWidth - result.bodyContentWidth), 1.0)
    }

    @MainActor
    func testReservedTrailingWidthSetterShrinksContentWithoutRerendering() async throws {
        let webView = try await renderMarkdown(
            """
            # Reserved width

            Content marker should survive a layout-only update.
            """,
            frameWidth: 1400,
            includeStyles: true
        )

        let resultJSON = try await evaluateStringJavaScript(
            """
            (function () {
              var content = document.getElementById('content');
              var beforeWidth = content.getBoundingClientRect().width;
              content.dataset.marker = 'kept';
              window.skimdown.setReservedTrailingWidth(300);
              var style = window.getComputedStyle(document.body);
              return JSON.stringify({
                beforeWidth: beforeWidth,
                afterWidth: content.getBoundingClientRect().width,
                marker: content.dataset.marker,
                reservedCSS: window.getComputedStyle(document.documentElement).getPropertyValue('--skimdown-reserved-trailing-width').trim(),
                paddingRight: parseFloat(style.paddingRight) || 0
              });
            })();
            """,
            in: webView
        )
        let result = try JSONDecoder().decode(ReservedWidthSetterResult.self, from: Data(resultJSON.utf8))

        XCTAssertEqual(result.marker, "kept")
        XCTAssertEqual(result.reservedCSS, "300px")
        XCTAssertGreaterThanOrEqual(result.paddingRight, 300)
        XCTAssertLessThan(result.afterWidth, result.beforeWidth)
    }

    @MainActor
    func testReservedTrailingWidthSetterRejectsNonFiniteValues() async throws {
        let webView = try await renderMarkdown(
            """
            # Reserved width sanitization

            Non-finite JavaScript inputs should not leave stale CSS lengths.
            """,
            frameWidth: 1400,
            includeStyles: true
        )

        let resultJSON = try await evaluateStringJavaScript(
            """
            (function () {
              window.skimdown.setReservedTrailingWidth(300);
              var finiteCSS = window.getComputedStyle(document.documentElement).getPropertyValue('--skimdown-reserved-trailing-width').trim();
              window.skimdown.setReservedTrailingWidth(Infinity);
              var infinityCSS = window.getComputedStyle(document.documentElement).getPropertyValue('--skimdown-reserved-trailing-width').trim();
              window.skimdown.setReservedTrailingWidth(300);
              window.skimdown.setReservedTrailingWidth(NaN);
              var nanCSS = window.getComputedStyle(document.documentElement).getPropertyValue('--skimdown-reserved-trailing-width').trim();
              return JSON.stringify({
                finiteCSS: finiteCSS,
                infinityCSS: infinityCSS,
                nanCSS: nanCSS
              });
            })();
            """,
            in: webView
        )
        let result = try JSONDecoder().decode(ReservedWidthSanitizationResult.self, from: Data(resultJSON.utf8))

        XCTAssertEqual(result.finiteCSS, "300px")
        XCTAssertEqual(result.infinityCSS, "0px")
        XCTAssertEqual(result.nanCSS, "0px")
    }

    @MainActor
    func testRenderPayloadPreservesReservedTrailingWidth() async throws {
        let webView = try await renderMarkdown(
            """
            # Reserved payload

            This render starts with a reserved trailing width.
            """,
            frameWidth: 1400,
            includeStyles: true,
            reservedTrailingWidth: 300
        )

        let result = try await previewLayoutResult(in: webView)

        XCTAssertEqual(result.reservedTrailingWidth, "300px")
        XCTAssertGreaterThanOrEqual(result.paddingRight, 300)
        XCTAssertLessThan(result.contentWidth, result.windowWidth - result.paddingLeft - 299)
    }

    @MainActor
    func testZeroReservedTrailingWidthUsesFullAvailableContentArea() async throws {
        let webView = try await renderMarkdown(
            """
            # Zero reserved width

            The content should use the full body content area.
            """,
            frameWidth: 1400,
            includeStyles: true
        )

        let result = try await previewLayoutResult(in: webView)

        XCTAssertEqual(result.reservedTrailingWidth, "0px")
        XCTAssertLessThan(result.paddingRight, 300)
        XCTAssertLessThanOrEqual(abs(result.contentWidth - result.bodyContentWidth), 1.0)
    }

    @MainActor
    func testPreviewLayoutMetricsReportsRenderedContentRect() async throws {
        let webView = try await renderMarkdown(
            """
            # Layout metrics

            The native TOC pane uses this content rect to stay near the rendered document.
            """,
            frameWidth: 1400,
            includeStyles: true
        )

        let resultJSON = try await evaluateStringJavaScript(
            "JSON.stringify(window.skimdown.previewLayoutMetrics());",
            in: webView
        )
        let result = try JSONDecoder().decode(PreviewLayoutMetricsResult.self, from: Data(resultJSON.utf8))

        XCTAssertEqual(result.viewportWidth, 1400, accuracy: 1)
        XCTAssertGreaterThan(result.contentWidth, 0)
        XCTAssertGreaterThan(result.contentRight, result.contentLeft)
        XCTAssertLessThanOrEqual(result.contentRight, result.viewportWidth)
    }

    @MainActor
    func testReservedTrailingWidthSetterRecomputesTableScrollCues() async throws {
        let webView = try await renderMarkdown(
            """
            | Name | Value |
            | --- | --- |
            | One | Two |
            """,
            frameWidth: 1400,
            includeStyles: true
        )

        let resultJSON = try await evaluateStringJavaScript(
            """
            (function () {
              var wrapper = document.querySelector('.table-scroll');
              var viewport = wrapper.querySelector('.table-scroll-viewport');
              var table = wrapper.querySelector('table');
              table.style.minWidth = '1100px';
              window.skimdown.setReservedTrailingWidth(300);
              return JSON.stringify({
                viewportOverflows: viewport.scrollWidth > viewport.clientWidth + 1,
                canScrollLeft: wrapper.classList.contains('can-scroll-left'),
                canScrollRight: wrapper.classList.contains('can-scroll-right')
              });
            })();
            """,
            in: webView
        )
        let result = try JSONDecoder().decode(TableCueState.self, from: Data(resultJSON.utf8))

        XCTAssertTrue(result.viewportOverflows)
        XCTAssertFalse(result.canScrollLeft)
        XCTAssertTrue(result.canScrollRight)
    }

    @MainActor
    func testExtremelyWideTableKeepsLocalHorizontalScroll() async throws {
        let webView = try await renderMarkdown(
            wideTableMarkdown(columnCount: 40),
            frameWidth: 1400,
            includeStyles: true
        )

        let resultJSON = try await evaluateStringJavaScript(
            """
            (function () {
              var wrapper = document.querySelector('.table-scroll');
              var viewport = wrapper.querySelector('.table-scroll-viewport');
              var initial = {
                wrapperCount: document.querySelectorAll('.table-scroll').length,
                viewportCount: document.querySelectorAll('.table-scroll-viewport').length,
                canScrollLeft: wrapper.classList.contains('can-scroll-left'),
                canScrollRight: wrapper.classList.contains('can-scroll-right'),
                viewportOverflows: viewport.scrollWidth > viewport.clientWidth + 1,
                pageScrollWidth: document.documentElement.scrollWidth,
                windowWidth: window.innerWidth
              };
              viewport.scrollLeft = viewport.scrollWidth;
              viewport.dispatchEvent(new Event('scroll'));
              return JSON.stringify({
                initial: initial,
                afterScroll: {
                  canScrollLeft: wrapper.classList.contains('can-scroll-left'),
                  canScrollRight: wrapper.classList.contains('can-scroll-right')
                }
              });
            })();
            """,
            in: webView
        )
        let result = try JSONDecoder().decode(TableLocalScrollResult.self, from: Data(resultJSON.utf8))

        XCTAssertEqual(result.initial.wrapperCount, 1)
        XCTAssertEqual(result.initial.viewportCount, 1)
        XCTAssertTrue(result.initial.viewportOverflows)
        XCTAssertFalse(result.initial.canScrollLeft)
        XCTAssertTrue(result.initial.canScrollRight)
        XCTAssertTrue(result.afterScroll.canScrollLeft)
        XCTAssertFalse(result.afterScroll.canScrollRight)
        XCTAssertLessThanOrEqual(result.initial.pageScrollWidth, result.initial.windowWidth + 1)
    }

    @MainActor
    private func renderMarkdown(
        _ markdown: String,
        copyCodeMessageHandler: WKScriptMessageHandler? = nil,
        activeHeadingMessageHandler: WKScriptMessageHandler? = nil,
        additionalScripts: [String] = [],
        additionalStyles: [String] = [],
        frameWidth: CGFloat = 800,
        includeStyles: Bool = false,
        reservedTrailingWidth: Double = 0
    ) async throws -> WKWebView {
        let configuration = WKWebViewConfiguration()
        if let copyCodeMessageHandler {
            configuration.userContentController.add(copyCodeMessageHandler, name: "copyCode")
        }
        if let activeHeadingMessageHandler {
            configuration.userContentController.add(activeHeadingMessageHandler, name: "activeHeading")
        }
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: frameWidth, height: 1000), configuration: configuration)
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

        webView.loadHTMLString(
            try rendererHTML(
                markdown: markdown,
                additionalScripts: additionalScripts,
                additionalStyles: additionalStyles,
                includeStyles: includeStyles,
                reservedTrailingWidth: reservedTrailingWidth
            ),
            baseURL: Bundle.main.bundleURL
        )
        await fulfillment(of: [navigationFinished], timeout: 5)
        webView.navigationDelegate = nil

        return webView
    }

    private func rendererHTML(
        markdown: String,
        additionalScripts: [String] = [],
        additionalStyles: [String] = [],
        includeStyles: Bool = false,
        reservedTrailingWidth: Double = 0
    ) throws -> String {
        let baseScripts = try [
            "vendor/markdown-it/markdown-it.min.js",
            "vendor/dompurify/purify.min.js"
        ].map(readWebResource)
        let rendererScripts = try [
            "renderer.js"
        ].map(readWebResource)
        let scripts = (
            baseScripts +
            additionalScripts +
            rendererScripts
        ).joined(separator: "\n")
        var styleSources = additionalStyles
        if includeStyles {
            styleSources.insert(try readWebResource("skimdown.css"), at: 0)
        }
        let styles = styleSources.isEmpty ? "" : "<style>\(styleSources.joined(separator: "\n"))</style>"

        let payload: [String: Any] = [
            "markdown": markdown,
            "baseURL": Bundle.main.bundleURL.absoluteString,
            "rootURL": Bundle.main.bundleURL.absoluteString,
            "localFileScheme": LocalFileSchemeHandler.scheme,
            "theme": "system",
            "fontSize": 16,
            "renderID": 1,
            "restoreScrollY": 0,
            "reservedTrailingWidth": reservedTrailingWidth
        ]

        return """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            \(styles)
          </head>
          <body>
            <main id="content"></main>
            <script>\(scripts)</script>
            <script>window.skimdown.render(\(try jsonObject(payload)));</script>
          </body>
        </html>
        """
    }

    private func wideTableMarkdown(columnCount: Int) -> String {
        let headers = (1...columnCount).map { "Column\($0)WideValue" }.joined(separator: " | ")
        let separators = Array(repeating: "---", count: columnCount).joined(separator: " | ")
        let values = (1...columnCount).map { "Cell\($0)WideValue" }.joined(separator: " | ")
        return """
        | \(headers) |
        | \(separators) |
        | \(values) |
        """
    }

    @MainActor
    private func previewLayoutResult(in webView: WKWebView) async throws -> PreviewLayoutResult {
        let resultJSON = try await evaluateStringJavaScript(
            """
            (function () {
              var content = document.getElementById('content');
              var bodyStyle = window.getComputedStyle(document.body);
              return JSON.stringify({
                contentWidth: content.getBoundingClientRect().width,
                paddingLeft: parseFloat(bodyStyle.paddingLeft) || 0,
                paddingRight: parseFloat(bodyStyle.paddingRight) || 0,
                bodyContentWidth: window.innerWidth - (parseFloat(bodyStyle.paddingLeft) || 0) - (parseFloat(bodyStyle.paddingRight) || 0),
                windowWidth: window.innerWidth,
                reservedTrailingWidth: window.getComputedStyle(document.documentElement).getPropertyValue('--skimdown-reserved-trailing-width').trim()
              });
            })();
            """,
            in: webView
        )
        return try JSONDecoder().decode(PreviewLayoutResult.self, from: Data(resultJSON.utf8))
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

    @MainActor
    private func waitForJavaScriptCondition(_ script: String, in webView: WKWebView) async throws {
        let timeout = Date().addingTimeInterval(2)
        while Date() < timeout {
            let result = try await evaluateStringJavaScript("String(Boolean(\(script)))", in: webView)
            if result == "true" {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw RendererAnchorTestError.scriptEvaluationFailed("Timed out waiting for JavaScript condition: \(script)")
    }

    private static let mermaidStubScript = """
    window.mermaid = {
      initialize: function () {},
      run: function (options) {
        (options.nodes || []).forEach(function (node) {
          node.innerHTML = [
            '<svg id="diagram" viewBox="0 0 1200 240" width="100%" style="max-width: 1200px;" xmlns="http://www.w3.org/2000/svg">',
            '<defs><marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto"><path d="M0,0 L0,6 L9,3 z"></path></marker></defs>',
            '<style>#arrowhead path { fill: currentColor; }</style>',
            '<path id="flow-line" d="M24 96 H1160" marker-end="url(#arrowhead)"></path>',
            '<text x="24" y="72">Wide Mermaid flow</text>',
            '</svg>'
          ].join('');
        });
        return Promise.resolve();
      }
    };
    """

    private static let mermaidModalTestStyle = """
    html, body {
      width: 800px;
      height: 600px;
      margin: 0;
    }
    .mermaid-modal {
      position: fixed;
      inset: 0;
      display: flex;
      padding: 0;
    }
    .mermaid-modal-panel {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-width: 0;
      min-height: 0;
    }
    .mermaid-modal-header {
      flex: 0 0 50px;
    }
    .mermaid-modal-frame {
      display: flex;
      flex: 1 1 auto;
      align-items: center;
      justify-content: center;
      min-height: 0;
      overflow: hidden;
      padding: 0;
    }
    .mermaid-modal-viewport {
      flex: 0 0 auto;
    }
    """
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

private struct MermaidExpandPaneResult: Decodable {
    let modalOpened: Bool
    let bodyLockedAfterOpen: Bool
    let htmlLockedAfterOpen: Bool
    let modalSVGWidthAttribute: String
    let modalSVGHeightAttribute: String
    let modalSVGStyleWidth: String
    let modalSVGStyleHeight: String
    let modalSVGStyleMaxWidth: String
    let baselineZoom: Double
    let initialZoom: Double
    let tabFromModalFocusesFirstControl: Bool
    let shiftTabFromModalFocusesLastControl: Bool
    let zoomAfterZoomIn: Double
    let zoomAfterResizeEvent: Double
    let baselineAfterResizeEvent: Double
    let zoomAfterReset: Double
    let baselineAfterResizeReset: Double
    let panXAfterReset: String
    let panYAfterReset: String
    let transformAfterZoom: String
    let transformAfterReset: String
    let stayedOpenAfterDragReleaseOnBackdrop: Bool
    let modalExistsAfterClose: Bool
    let bodyLockedAfterClose: Bool
    let htmlLockedAfterClose: Bool
    let openerFocusAttemptedAfterHidden: Bool
    let focusRestoredToContainer: Bool
    let originalMarkerID: String
    let modalMarkerID: String
    let modalMarkerEnd: String
}

private struct SearchBlockBoundaryResult: Decodable {
    let count: Int
}

private struct RenderTokenResult: Decodable {
    let first: String?
    let second: String?
}

private struct TableOfContentsEntryResult: Decodable, Equatable {
    let level: Int
    let title: String
    let id: String
}

private struct ActiveHeadingMessage: Equatable {
    let renderID: Int
    let headingID: String?
}

private struct PreviewLayoutResult: Decodable {
    let contentWidth: Double
    let paddingLeft: Double
    let paddingRight: Double
    let bodyContentWidth: Double
    let windowWidth: Double
    let reservedTrailingWidth: String
}

private struct ReservedWidthSetterResult: Decodable {
    let beforeWidth: Double
    let afterWidth: Double
    let marker: String
    let reservedCSS: String
    let paddingRight: Double
}

private struct ReservedWidthSanitizationResult: Decodable {
    let finiteCSS: String
    let infinityCSS: String
    let nanCSS: String
}

private struct TableLocalScrollResult: Decodable {
    let initial: TableLocalScrollInitialState
    let afterScroll: TableLocalScrollAfterState
}

private struct TableLocalScrollInitialState: Decodable {
    let wrapperCount: Int
    let viewportCount: Int
    let viewportOverflows: Bool
    let canScrollLeft: Bool
    let canScrollRight: Bool
    let pageScrollWidth: Double
    let windowWidth: Double
}

private struct TableLocalScrollAfterState: Decodable {
    let canScrollLeft: Bool
    let canScrollRight: Bool
}

private struct TableCueState: Decodable {
    let viewportOverflows: Bool
    let canScrollLeft: Bool
    let canScrollRight: Bool
}

private struct PreviewLayoutMetricsResult: Decodable {
    let contentLeft: Double
    let contentRight: Double
    let contentWidth: Double
    let viewportWidth: Double
}

private struct CodeCopyFeedbackResult: Decodable {
    let initial: CodeCopyButtonState
    let firstClick: CodeCopyButtonState
    let secondClick: CodeCopyButtonState
    let afterFirstTimer: CodeCopyButtonState
    let afterSecondTimer: CodeCopyButtonState
    let timerCount: Int
    let firstTimerDelay: Int
    let secondTimerDelay: Int
    let firstTimerCleared: Bool
}

private struct CodeCopyButtonState: Decodable {
    let text: String
    let ariaLabel: String?
    let hasCopiedClass: Bool
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

private final class ScriptMessageRecorder: NSObject, WKScriptMessageHandler {
    private(set) var messages: [String] = []
    private let onMessage: () -> Void

    init(onMessage: @escaping () -> Void) {
        self.onMessage = onMessage
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? String {
            messages.append(body)
        }
        onMessage()
    }
}

private final class ActiveHeadingMessageRecorder: NSObject, WKScriptMessageHandler {
    private(set) var messages: [ActiveHeadingMessage] = []

    func removeAll() {
        messages.removeAll()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let renderID = body["renderID"] as? Int else {
            return
        }
        let headingID = body["headingID"] as? String
        messages.append(ActiveHeadingMessage(renderID: renderID, headingID: headingID?.isEmpty == true ? nil : headingID))
    }
}
