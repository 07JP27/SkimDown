# Open folders

SkimDown reads one folder per window. Each window owns its folder, selected file, sidebar state, and preview state.

## Open a folder

Use any of these entry points:

- `File > Open Folder...`
- `Cmd+O`
- the empty-state `Open Folder...` button
- drag a folder into an empty SkimDown window
- command line: pass a folder path as the first argument (see below)

If a window already has a folder open and you drop another folder onto it, SkimDown opens the new folder in a separate window.

## Initial file selection

After opening a folder, SkimDown chooses what to display in this order:

1. The last Markdown file opened for that folder
2. `README.md`
3. The first Markdown file in the tree
4. Empty state if the folder has no Markdown

## Recent folders

Recently opened folders are available from `File > Open Recent`. Folder access is restored with security-scoped bookmarks when possible.

## Command line

Launch SkimDown from the terminal:

```sh
# Open with specific folder
skimdown /xxx/yyy/zzz

# Open with current folder
skimdown
```

When launched with a folder path argument, SkimDown opens that folder directly instead of restoring the previous session. When launched without arguments from the terminal, it opens the current working directory.

To set up the `skimdown` command, create a symbolic link to the app binary:

```sh
ln -s /Applications/SkimDown.app/Contents/MacOS/SkimDown /usr/local/bin/skimdown
```

