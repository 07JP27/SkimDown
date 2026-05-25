# Custom Color Theme

SkimDown lets you define and switch between custom color themes for the
preview area. Themes are written as JSON files in the
[VS Code color theme format](https://code.visualstudio.com/api/references/theme-color),
so existing VS Code theme assets can be reused.

## Where themes live

Drop JSON files into:

```
~/Library/Application Support/SkimDown/Themes/
```

Open the folder quickly from the app via **View → Theme → Open Themes Folder**.

## JSON format

Each file is a standalone VS Code color theme:

```json
{
  "name": "My Theme",
  "type": "dark",
  "colors": {
    "editor.background": "#1e1e1e",
    "editor.foreground": "#d4d4d4",
    "textLink.foreground": "#3794ff"
  }
}
```

- `name` — the label shown in **View → Theme**. Falls back to the file name when omitted.
- `type` — `"light"` or `"dark"`. Picks the light/dark code highlight CSS and the Mermaid theme.
- `colors` — VS Code color keys. Only a small set is used by SkimDown; the rest are ignored.

`tokenColors` (syntax highlighting) is not yet supported. Code blocks use
GitHub's light or dark highlight palette based on `type`.

## Color key mapping

| SkimDown CSS variable    | VS Code keys (in priority order)                                              |
| ------------------------- | ----------------------------------------------------------------------------- |
| `--skimdown-bg`           | `editor.background`                                                           |
| `--skimdown-fg`           | `editor.foreground`, `foreground`                                             |
| `--skimdown-muted`        | `descriptionForeground`, `disabledForeground`                                 |
| `--skimdown-border`       | `panel.border`, `editorGroup.border`, `editorWidget.border`, `contrastBorder` |
| `--skimdown-subtle`       | `editorGroupHeader.tabsBackground`, `editor.lineHighlightBackground`, `sideBar.background` |
| `--skimdown-surface`      | `editorWidget.background`, `editor.background`                                |
| `--skimdown-accent`       | `textLink.foreground`, `editorLink.activeForeground`, `focusBorder`           |
| `--skimdown-mark`         | `editor.findMatchHighlightBackground`                                         |
| `--skimdown-current-mark` | `editor.findMatchBackground`                                                  |

Missing keys fall back to SkimDown's built-in light or dark palette based on the theme `type`.

## Reloading themes

The Themes folder is **not** watched automatically. After adding or editing a
JSON file, choose **View → Theme → Reload Themes** to refresh the list.

If the theme currently in use is deleted, SkimDown falls back to the System
theme on the next reload or launch.
