# SkimDown

**Markdown, in reading mode.**

SkimDown is a lightweight Markdown viewer for macOS. Simply open a folder and it automatically scans the Markdown files inside, displays them in a tree view, and renders them beautifully. It intentionally has no editing features — it's built purely for reading.

---

## Features

- 📂 **Folder-based** — Open a folder and it automatically scans `.md` / `.markdown` files
- 🌲 **Sidebar tree** — VS Code-style tree view for quick file navigation
- 🎨 **Dark / Light theme** — Automatically follows system appearance
- 📐 **Math support** — Beautiful math rendering with KaTeX
- 📊 **Diagrams** — Flowcharts and sequence diagrams via Mermaid
- 🔍 **In-page search** — Incremental search within the current document
- 💻 **Code highlighting** — Multi-language syntax highlighting with highlight.js
- 🔗 **Internal links** — Seamlessly navigate relative links between Markdown files
- 🔒 **Sandbox-safe** — Only reads from the selected folder, ensuring safe operation

## Supported Markdown Syntax

SkimDown supports the following syntax. Click each link to see a sample.

### Basics

| Syntax | Sample |
|---|---|
| Headings (h1–h6) | [headings.md](en/basics/headings.md) |
| Text formatting (bold, italic, strikethrough) | [text-formatting.md](en/basics/text-formatting.md) |
| Links and images | [links-and-images.md](en/basics/links-and-images.md) |
| Lists (ordered, task) | [lists.md](en/basics/lists.md) |

### Block Elements

| Syntax | Sample |
|---|---|
| Blockquotes | [blockquotes.md](en/blocks/blockquotes.md) |
| Code blocks | [code-blocks.md](en/blocks/code-blocks.md) |
| Tables | [tables.md](en/blocks/tables.md) |
| Horizontal rules | [horizontal-rules.md](en/blocks/horizontal-rules.md) |

### Extended Syntax

| Syntax | Sample |
|---|---|
| Footnotes | [footnotes.md](en/extended/footnotes.md) |
| Math (KaTeX) | [math.md](en/extended/math.md) |
| Diagrams (Mermaid) | [mermaid.md](en/extended/mermaid.md) |
| HTML elements | [html-elements.md](en/extended/html-elements.md) |

### Miscellaneous

| File | Purpose |
|---|---|
| [deep-file.md](en/deep/nested/folder/deep-file.md) | Verifying tree display for deeply nested files |
| [all-in-one.md](en/misc/all-in-one.md) | All syntax in one file |
| [sample.markdown](en/misc/sample.markdown) | Verifying `.markdown` extension support |

---

## Tech Stack

- **Swift 6** + **AppKit** + **WKWebView**
- Markdown parsing: [markdown-it](https://github.com/markdown-it/markdown-it)
- Math: [KaTeX](https://katex.org)
- Diagrams: [Mermaid](https://mermaid.js.org)
- Code highlighting: [highlight.js](https://highlightjs.org)
- Sanitization: [DOMPurify](https://github.com/cure53/DOMPurify)

> All libraries are bundled with the app — no CDN access required.
