# Tables

## Basic Table

| Name | Role | Language |
|---|---|---|
| AppDelegate | App startup | Swift |
| MarkdownScanner | File scanning | Swift |
| renderer.js | Markdown rendering | JavaScript |

## Column Alignment

| Left-aligned | Center-aligned | Right-aligned |
|:---|:---:|---:|
| Apple | 🍎 | ¥150 |
| Orange | 🍊 | ¥80 |
| Grape | 🍇 | ¥300 |
| Strawberry | 🍓 | ¥500 |

## Table with Formatting

| Feature | Status | Notes |
|---|---|---|
| **Folder scanning** | ✅ Done | Implemented in `MarkdownScanner` |
| *Sidebar* | ✅ Done | Tree view supported |
| ~~Print feature~~ | ❌ Out of scope | Not needed for MVP |
| `Code highlighting` | ✅ Done | Uses highlight.js |
| [KaTeX](https://katex.org) | ✅ Done | Math rendering |

## Long Table (Horizontal Scroll Test)

| ID | Filename | Path | Size | Created | Updated | Extension | Encoding | Lines | Status |
|---|---|---|---|---|---|---|---|---|---|
| 1 | README.md | /samples/README.md | 2.1KB | 2025-01-01 | 2025-04-29 | .md | UTF-8 | 45 | Active |
| 2 | headings.md | /samples/basics/headings.md | 0.8KB | 2025-01-01 | 2025-04-29 | .md | UTF-8 | 30 | Active |
| 3 | code-blocks.md | /samples/blocks/code-blocks.md | 3.5KB | 2025-01-01 | 2025-04-29 | .md | UTF-8 | 120 | Active |
| 4 | math.md | /samples/extended/math.md | 1.2KB | 2025-01-01 | 2025-04-29 | .md | UTF-8 | 50 | Active |
| 5 | mermaid.md | /samples/extended/mermaid.md | 1.8KB | 2025-01-01 | 2025-04-29 | .md | UTF-8 | 65 | Active |

## Multi-line Table

| Component | Description |
|---|---|
| MarkdownScanner | Recursively scans the target folder to collect `.md` / `.markdown` files. Skips hidden files and excluded directories (`.git`, `node_modules`, etc.). |
| MarkdownTreeBuilder | Converts collected files into a tree structure. Sorts folders first then by name, excluding empty folders. |
| MarkdownRenderer | Generates HTML from Markdown text. Based on markdown-it, extended with plugins for footnotes, math, and Mermaid. |
| LinkRouter | Handles link clicks. Distinguishes between anchor links, internal Markdown links, and external links, routing each appropriately. |

## Single Column Table

| Supported Extensions |
|---|
| `.md` |
| `.markdown` |
