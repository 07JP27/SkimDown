# Git changes

When the opened folder is the root of a Git working tree, SkimDown can highlight what changed since the last commit.

## Turn it on

Choose `View > Show Git Changes` (`Shift+Cmd+D`). The setting is off by default, applies to every window, and is saved automatically.

## What is compared

SkimDown compares the current files with `HEAD`. All uncommitted changes are shown, whether or not they are staged.

The folder itself must be the working-tree root: it must directly contain `.git`. Linked worktrees and submodules (where `.git` is a file) are supported. Subfolders of a repository are not decorated.

## Preview

Changed blocks get a light background and a colored bar in a gutter column to the left of the text. The bars line up in one column whatever the block type or list depth, and consecutive blocks with the same kind of change share one continuous bar:

- Green: added blocks
- Yellow: modified blocks
- Red marker: deleted lines

Paragraphs, headings, list items, table rows, code blocks, horizontal rules, HTML blocks, front matter, Mermaid diagrams, and math blocks are marked as whole blocks. Word-level changes are not shown.

A red `N lines deleted` marker appears where lines were removed, and a yellow `Show previous version` marker appears before modified blocks. Click a marker to expand the previous Markdown text. That text is shown as plain text and is excluded from in-document search.

Files that are not in `HEAD` are shown as entirely added. Files ignored by `.gitignore` are not decorated.

## Sidebar

The sidebar uses VS Code-style decorations:

- `M` with a yellow name: modified
- `U` with a green name: untracked
- `A` with a green name: added to the index but not committed
- A colored dot: a folder that contains changes

Sidebar decorations are not shown when a single file is opened. The preview is still highlighted when the file's parent folder is a working-tree root.

## Updates

The highlights refresh when Markdown files change and when commits, staging, or branch switches change `HEAD`, refs, or the index.

## Requirements

SkimDown runs the system `git` from the Xcode Command Line Tools in read-only mode. If the tools are not installed, Git changes are not shown and the preview works normally. See [Privacy & Permissions](../security.md) for details.
