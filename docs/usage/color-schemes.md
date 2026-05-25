# Custom Color Theme

SkimDown lets you define and switch between custom color themes for the
preview area. Themes are written as JSON or JSONC files in the
[VS Code color theme format](https://code.visualstudio.com/api/references/theme-color),
so existing VS Code theme assets can be reused.

## Where themes live

Drop JSON or JSONC files into:

```
~/Library/Application Support/SkimDown/Themes/
```

Open the folder quickly from the app via **View → Theme → Open Themes Folder**.

## JSON format

Each file is a standalone VS Code color theme. Comments and trailing commas used
by VS Code theme files are accepted. For example, save this as
`solarized-light.json`:

```json
{
  "$schema": "vscode://schemas/color-theme",
  "name": "Solarized Light",
  "type": "light",
  "colors": {
    "editor.background": "#fdf6e3",
    "editor.foreground": "#586e75",
    "descriptionForeground": "#93a1a1",
    "panel.border": "#eee8d5",
    "editorGroupHeader.tabsBackground": "#eee8d5",
    "editorWidget.background": "#fdf6e3",
    "textLink.foreground": "#268bd2",
    "editor.findMatchHighlightBackground": "#f8e8a5",
    "editor.findMatchBackground": "#fad880"
  }
}
```

- `name` — the label shown in **View → Theme**. Falls back to the file name when omitted.
- `type` — `"light"` or `"dark"`. Picks the light/dark code highlight CSS and the Mermaid theme.
- `colors` — VS Code color keys. Only a small set is used by SkimDown; the rest are ignored.

`tokenColors` (syntax highlighting) is not yet supported. Code blocks use
GitHub's light or dark highlight palette based on `type`.

## Color key mapping

When multiple keys are listed, SkimDown uses the first key found in the theme.

| Preview element | VS Code color keys |
| --------------- | ------------------ |
| Background | `editor.background` |
| Text | `editor.foreground`, `foreground` |
| Secondary text | `descriptionForeground`, `disabledForeground` |
| Borders | `panel.border`, `editorGroup.border`, `editorWidget.border`, `contrastBorder` |
| Subtle backgrounds | `editorGroupHeader.tabsBackground`, `editor.lineHighlightBackground`, `sideBar.background` |
| Panel backgrounds | `editorWidget.background`, `editor.background` |
| Links and accents | `textLink.foreground`, `editorLink.activeForeground`, `focusBorder` |
| Search highlights | `editor.findMatchHighlightBackground` |
| Current search match | `editor.findMatchBackground` |

Missing keys fall back to SkimDown's built-in light or dark palette based on the theme `type`.

## Reloading themes

The Themes folder is **not** watched automatically. After adding or editing a
JSON or JSONC file, choose **View → Theme → Reload Themes** to refresh the list.

If the theme currently in use is deleted, SkimDown falls back to the System
theme on the next reload or launch.
