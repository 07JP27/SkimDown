# Privacy & Permissions

SkimDown is a local, read-only Markdown viewer. It is designed to read the folder you choose, not to manage or modify your files.

## Folder access

SkimDown asks you to choose a folder with the macOS folder picker. It only reads folders that you explicitly select.

Recent folders and the last opened folder reopen automatically because SkimDown remembers them as macOS file bookmarks. Bookmarks track folder moves and renames so the entries keep working after you reorganize your filesystem.

## Read-only behavior

SkimDown does not edit, save, export, print, or modify Markdown files. It is built for reading and navigation only — it does not write back to the Markdown files it opens.

## Git changes

When `View > Show Git Changes` is on and the opened folder is the root of a Git working tree, SkimDown runs the system `/usr/bin/git` to compare files with `HEAD`. It only uses read-only commands (`rev-parse`, `ls-tree`, `ls-files`, `cat-file`, `check-ignore`). It does not use `git status` or `git diff`, which can run programs configured by a repository, and it disables fsmonitor, lazy fetching of missing objects, and optional locks. Git never contacts a remote and nothing in the repository is changed.

To keep the preview up to date, SkimDown reads and watches the repository's git directory, which can be outside the opened folder for linked worktrees and submodules. Git is not run while the setting is off or for folders that are not a working-tree root.

## Local file boundaries

Relative Markdown links and local images are resolved only when the target stays inside the folder you opened. SkimDown does not use a Markdown file to browse arbitrary local files outside that folder.

## Sanitized HTML

Embedded HTML is sanitized before display. Unsafe tags, event attributes, and dangerous URL schemes are removed.

## External content

External links open in your default browser. External images referenced by Markdown may be loaded in the preview.

## No external transmission

SkimDown does not send your Markdown text or folder contents to external services. External links open in your browser, and externally hosted images may be requested by the preview as described above.
