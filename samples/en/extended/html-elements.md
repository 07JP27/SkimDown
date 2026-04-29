# HTML Elements

Samples of HTML elements that can be used within Markdown.

## Keyboard Shortcuts (kbd)

Keyboard shortcuts available in SkimDown:

| Action | Shortcut |
|---|---|
| Open folder | <kbd>⌘</kbd> + <kbd>O</kbd> |
| Find in page | <kbd>⌘</kbd> + <kbd>F</kbd> |
| Next search result | <kbd>⌘</kbd> + <kbd>G</kbd> |
| Previous search result | <kbd>⌘</kbd> + <kbd>Shift</kbd> + <kbd>G</kbd> |
| Increase font size | <kbd>⌘</kbd> + <kbd>+</kbd> |
| Decrease font size | <kbd>⌘</kbd> + <kbd>-</kbd> |

You can also use them inline: press <kbd>Ctrl</kbd> + <kbd>C</kbd> to copy, <kbd>Ctrl</kbd> + <kbd>V</kbd> to paste.

## Collapsible Sections (details / summary)

<details>
<summary>SkimDown's Tech Stack (click to expand)</summary>

- **Language:** Swift 6
- **UI Framework:** AppKit
- **Markdown Parser:** markdown-it
- **Math:** KaTeX
- **Diagrams:** Mermaid
- **Code Highlighting:** highlight.js
- **Sanitization:** DOMPurify

</details>

<details>
<summary>Supported Markdown Extensions</summary>

| Extension | Supported |
|---|---|
| `.md` | ✅ |
| `.markdown` | ✅ |
| `.txt` | ❌ |
| `.rst` | ❌ |

</details>

<details>
<summary>Excluded Directories</summary>

The following directories are automatically skipped by `MarkdownScanner`:

1. `.git`
2. `node_modules`
3. `.build`
4. `DerivedData`

These are version control or build artifacts that don't need to be displayed in a Markdown viewer.

</details>

### Nested Collapsible Sections

<details>
<summary>Layer Architecture</summary>

<details>
<summary>App Layer</summary>

Handles app startup, menus, and window management.

</details>

<details>
<summary>Core Layer</summary>

Handles folder permissions, settings persistence, and file monitoring.

</details>

<details>
<summary>Viewer Layer</summary>

Handles Markdown rendering using WKWebView.

</details>

</details>

## Highlight (mark)

SkimDown's key feature is that it is a <mark>read-only Markdown viewer</mark>.

Important point: <mark>Sandbox support</mark> ensures it only reads from the folder selected by the user.

Both <mark>Dark mode</mark> and <mark>Light mode</mark> are supported.
