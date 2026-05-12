# Preview

## Supported syntax

SkimDown targets GitHub-Flavored-Markdown-like reading. Below is the full list of supported syntax, grouped by category.

### Basic Markdown (CommonMark)

| Syntax | Example |
|---|---|
| Headings | `# H1` … `###### H6`, setext (`===` / `---`) |
| Paragraphs | Blank line between paragraphs |
| Bold | `**text**` or `__text__` |
| Italic | `*text*` or `_text_` |
| Bold + Italic | `***text***` |
| Inline code | `` `code` `` |
| Code blocks | Fenced (triple backticks) or indented (4 spaces) |
| Links | `[text](url)`, `[text][ref]` |
| Images | `![alt](url)` |
| Unordered lists | `- item`, `* item`, `+ item` |
| Ordered lists | `1. item` |
| Blockquotes | `> text` |
| Horizontal rules | `---`, `***`, `___` |
| Hard line breaks | Two trailing spaces or `\` |
| Backslash escapes | `\*`, `\[`, etc. |
| HTML entities | `&amp;`, `&#x1F600;`, etc. |

### GFM extensions

| Syntax | Example |
|---|---|
| Tables | Pipe-separated with header row and alignment (`:---`, `:---:`, `---:`) |
| Task lists | `- [x] Done`, `- [ ] Todo` |
| Strikethrough | `~~text~~` |
| Autolinks | Bare URLs, `www.` links, and email addresses |

### GitHub-specific syntax

| Syntax | Example |
|---|---|
| Alerts | `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]` |
| Emoji shortcodes | `:smile:`, `:+1:`, `:rocket:` |
| Single-tilde strikethrough | `~text~` |

### Math (KaTeX)

| Form | Scope | Example |
|---|---|---|
| `$…$` | Inline | `$E = mc^2$` |
| `$$…$$` | Block (display) | `$$\int_0^\infty …$$` |
| `\(…\)` | Inline | `\(\sqrt{x}\)` |
| `\[…\]` | Block (display) | `\[\int …\]` |
| `` ```math `` fenced block | Block (display) | Fenced code block with `math` language |
| `` $`…`$ `` | Inline | `` $`\binom{n}{k}`$ `` |

### Mermaid diagrams

Fenced code blocks with the `mermaid` language identifier are rendered as interactive diagrams. Supports flowcharts, sequence diagrams, class diagrams, Gantt charts, and more. Theme follows the app's light/dark setting. See [Mermaid diagrams](#mermaid-diagrams) below for zoom/pan details.

### Other extensions

| Feature | Description |
|---|---|
| Footnotes | `[^label]` references with `[^label]: definition` |
| HTML elements | `<details>`, `<summary>`, `<sub>`, `<sup>`, `<mark>`, `<kbd>` |
| Image size | `![alt](url =WxH)` syntax for specifying dimensions |
| Syntax highlighting | Language-specific code coloring for fenced code blocks |

## Themes and zoom

Use `View > Theme` to choose System, Light, or Dark. Use `View > Zoom` to adjust preview font size.

## Mermaid diagrams

Each Mermaid diagram is rendered inside a card sized to the body width. Text inside diagrams is automatically scaled so it never appears larger than the surrounding body text, keeping the visual flow from prose to diagram natural.

You can zoom and pan a diagram when you want to inspect details:

- Hover the card (or focus it with `Tab`) to reveal the toolbar in the top-right corner.
- Use **+** / **−** to zoom in and out, or **Reset** to return to the default size.
- `⌘` (or `Ctrl`) + mouse wheel zooms in and out.
- When zoomed in, or when the diagram is larger than the card, click and drag inside the card to pan.

## Links

Page anchors scroll within the current preview. Relative links to Markdown files open inside SkimDown and update the tree selection. External links open in the default browser.

## Local images

Local images are displayed only when they are inside the opened folder. Image files are not shown as standalone sidebar items.

