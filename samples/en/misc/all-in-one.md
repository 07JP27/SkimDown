# All Syntax Overview (All-in-One)

This file combines all Markdown syntax supported by SkimDown in a single document.

---

## Headings

### h3 Heading

#### h4 Heading

##### h5 Heading

###### h6 Heading

## Text Formatting

**Bold** / *Italic* / ***Bold Italic*** / ~~Strikethrough~~ / `Inline code`

## Links and Images

- [Internal link](../../README.md)
- [External link](https://github.com)
- [Anchor link](#headings)

![Octocat](https://github.githubassets.com/images/icons/emoji/octocat.png)

## Lists

### Unordered

- Item A
  - Sub-item 1
  - Sub-item 2
- Item B

### Ordered

1. First
2. Second
3. Third

### Task List

- [x] Completed task
- [ ] Incomplete task

## Blockquotes

> This is a blockquote.
>
> > This is a nested blockquote.

## Code Blocks

```swift
struct SkimDown {
    let name = "SkimDown"
    let platform = "macOS"

    func greet() -> String {
        "Markdown, in reading mode."
    }
}
```

```javascript
const md = window.markdownit({ html: true, linkify: true });
const html = md.render("# Hello, SkimDown!");
document.getElementById("content").innerHTML = html;
```

## Tables

| Feature | Status | Notes |
|:---|:---:|---:|
| Markdown display | ✅ | markdown-it |
| Math | ✅ | KaTeX |
| Diagrams | ✅ | Mermaid |
| Code highlighting | ✅ | highlight.js |

## Horizontal Rule

---

## Footnotes

SkimDown is a lightweight viewer[^1]. It can also render math with KaTeX[^2].

[^1]: Read-only with no editing features.
[^2]: Supports both inline and display math.

## Math

Inline: $E = mc^2$

Display:

$$
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
$$

## Mermaid

```mermaid
flowchart LR
    A[Markdown] --> B[markdown-it]
    B --> C[HTML]
    C --> D[DOMPurify]
    D --> E[Display in WebView]
```

## HTML Elements

<kbd>⌘</kbd> + <kbd>O</kbd> to open a folder

<details>
<summary>Show details</summary>

Collapsed content is displayed here.

</details>

<mark>Highlighted text</mark>

---

The above covers all Markdown syntax supported by SkimDown.
