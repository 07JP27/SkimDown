# Open folders

SkimDown reads one folder per window. Each window owns its folder, selected file, sidebar state, and preview state.

## Open a folder

Use any of these entry points:

- `File > Open Folder...`
- `Cmd+O`
- the empty-state `Open Folder...` button
- drag a folder into an empty SkimDown window

If a window already has a folder open and you drop another folder onto it, SkimDown opens the new folder in a separate window.

## Initial file selection

After opening a folder, SkimDown chooses what to display in this order:

1. The last Markdown file opened for that folder
2. `README.md`
3. The first Markdown file in the tree
4. Empty state if the folder has no Markdown

## Recent folders

Recently opened folders are available from `File > Open Recent`. Folder access is restored with security-scoped bookmarks when possible.

