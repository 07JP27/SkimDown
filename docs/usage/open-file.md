# Open files

SkimDown can preview a single Markdown file without opening a folder. In single-file mode the sidebar is hidden and only the preview is shown.

## Open a file

Use any of these entry points:

- `File > Open File...`
- `Shift+Cmd+O`
- drag a `.md` or `.markdown` file into an empty SkimDown window
- right-click a Markdown file in Finder and choose `Open With > SkimDown`
- command line: pass a file path as the first argument (see below)

If a window already has a folder open and you drop a Markdown file onto it, SkimDown opens the file in a new window.

## Behavior in single-file mode

- The sidebar is hidden and cannot be toggled.
- The window title shows the file name.
- Relative image paths and asset links that stay inside the file's parent directory are resolved normally. Links to other Markdown files are not followed — use folder mode for multi-file navigation.
- Live reload watches for changes to the file and refreshes the preview automatically.
- Dropping a folder onto a single-file window switches it to folder mode.

## Command line

```sh
# Open a specific file
skimdown /path/to/README.md
```

When a Markdown file path is given as the first argument, SkimDown opens it in single-file mode instead of restoring the previous session.
