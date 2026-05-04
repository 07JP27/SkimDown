# Preview

The preview is rendered with `WKWebView` and bundled Web assets. Normal Markdown rendering does not depend on a CDN.

## Supported Markdown

SkimDown targets GitHub-Flavored-Markdown-like reading:

- headings, paragraphs, emphasis, strikethrough
- unordered, ordered, and task lists
- code blocks and inline code
- tables
- blockquotes and horizontal rules
- links and autolinks
- local and external images
- footnotes
- KaTeX math
- Mermaid diagrams
- safe embedded HTML after sanitization

## Themes and zoom

Use `View > Theme` to choose System, Light, or Dark. Use `View > Zoom` to adjust preview font size.

## Mermaid diagrams

Each Mermaid diagram is rendered inside a card sized to the body width. Text inside diagrams is automatically scaled so it never appears larger than the surrounding body text, keeping the visual flow from prose to diagram natural.

You can zoom and pan a diagram when you want to inspect details:

- Hover the card (or focus it with `Tab`) to reveal the toolbar in the top-right corner.
- Use **+** / **−** to zoom in and out, or **Reset** to return to the default size.
- `⌘` (or `Ctrl`) + mouse wheel zooms in and out.
- When zoomed in, click and drag inside the card to pan.

## Links

Page anchors scroll within the current preview. Relative links to Markdown files open inside SkimDown and update the tree selection. External links open in the default browser.

## Local images

Local images are displayed only when they are inside the opened folder. Image files are not shown as standalone sidebar items.

