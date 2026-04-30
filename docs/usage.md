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

## More usage topics

- [Open folders](./usage/open-folder.md)
- [Preview](./usage/preview.md)
- [Search](./usage/search.md)
- [Live reload](./usage/reload.md)
- [Security model](./security.md)

