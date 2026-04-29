# .markdown Extension Test

This file is saved with the `.markdown` extension instead of `.md`.

SkimDown's `MarkdownScanner` supports both `.md` and `.markdown`. If this file appears in the sidebar tree, the `.markdown` extension is being recognized correctly.

## Verification Points

- [x] Displayed in the sidebar tree
- [ ] Content is rendered correctly
- [ ] Links from other files work

## Code Reference

Corresponding Swift code:

```swift
var skimdownIsMarkdownFile: Bool {
    let ext = pathExtension.lowercased()
    return ext == "md" || ext == "markdown"
}
```

> If this file is displayed, the above code is working correctly.
