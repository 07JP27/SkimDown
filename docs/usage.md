# Usage

SkimDown is designed around one flow: open a folder, skim its Markdown tree, and read the selected file in a clean preview.

## Core workflow

1. Open a folder with `File > Open Folder...`, `Cmd+O`, the empty-state button, or folder drag and drop.
2. Select a Markdown file from the sidebar.
3. Read the rendered preview.
4. Use `Cmd+F` to search within the current file.
5. Follow relative Markdown links to move between files.

## What appears in the sidebar

SkimDown shows `.md` and `.markdown` files only. It scans recursively, hides hidden files and folders, skips common generated directories, and omits empty folders that contain no Markdown.

## What does not appear

SkimDown is read-only. It does not edit Markdown, add comments, export, print, perform file-name search, or search across multiple files.

## Try with sample files

Want to see what SkimDown can render before opening your own folder? The repository ships a [`samples/`](https://github.com/07JP27/SkimDown/tree/main/samples) directory containing reference Markdown files that exercise every supported syntax.

The samples cover:

- **Basics** — headings, text formatting, links and images, lists
- **Block elements** — blockquotes, code blocks, tables, horizontal rules
- **Extended** — footnotes, math (KaTeX), diagrams (Mermaid), HTML elements
- **Miscellaneous** — deeply nested folders, an all-in-one file, and `.markdown` extension support

To try them:

1. Clone or download the repository.
2. In SkimDown choose **File → Open Folder…** and pick `samples/en` (English) or `samples/ja` (Japanese).
3. Browse the tree and read each sample.

See [`samples/README.md`](https://github.com/07JP27/SkimDown/blob/main/samples/README.md) for the full file index. SkimDown is read-only, so opening the samples folder will never modify or add anything in it.

## More usage topics

- [Open folders](./usage/open-folder.md)
- [Preview](./usage/preview.md)
- [Settings](./usage/settings.md)
- [Search](./usage/search.md)
- [Live reload](./usage/reload.md)
- [Security model](./security.md)

