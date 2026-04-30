# Installation

## System Requirements

- **macOS 26** (Tahoe) or later
- A folder containing `.md` or `.markdown` files

## Download & Install

1. Download the latest `.dmg` from the [Releases page](https://github.com/07JP27/SkimDown/releases)
2. Open the `.dmg` file and drag **SkimDown.app** to the **Applications** folder
3. Open SkimDown from Applications

## Removing the Quarantine Attribute

If you see the warning *"Apple could not verify 'SkimDown' is free of malware that may harm your Mac or compromise your privacy"*, run the following command in **Terminal** to remove the quarantine attribute:

```bash
xattr -dr com.apple.quarantine /Applications/SkimDown.app
```

::: warning
Please review the [source code](https://github.com/07JP27/SkimDown) and run at your own risk.
:::

## First Launch

1. Open SkimDown.
2. Choose **File → Open Folder…** (or press **⌘O**, or drag a folder onto the window).
3. Pick the folder that contains the Markdown files you want to read.

SkimDown uses the macOS folder picker to choose a folder to read. The app remembers the folder location using regular file bookmarks so recent folders can reopen later.

::: tip
SkimDown is **read-only**. It never edits, saves, exports, or modifies your Markdown files.
:::

## Updating

Download the newer `.dmg` from the [Releases page](https://github.com/07JP27/SkimDown/releases) and replace the existing **SkimDown.app** in your Applications folder. Re-run `xattr -dr com.apple.quarantine /Applications/SkimDown.app` if Gatekeeper warns again.

## Next Steps

After launch, continue with [Usage](./usage.md) to learn how to open folders, navigate the tree, preview Markdown, and search the current file.
