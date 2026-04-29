# Footnotes

## Basic Footnotes

SkimDown supports footnotes using the markdown-it-footnote plugin[^1].

Footnotes are displayed at the bottom of the document[^2].

[^1]: markdown-it-footnote is a plugin for markdown-it.
[^2]: Clicking a footnote number will jump to the corresponding footnote.

## Named Footnotes

Markdown was created by John Gruber[^gruber]. Since then, many extended syntaxes have emerged[^extensions].

[^gruber]: John Gruber is the author of Daring Fireball and the creator of Markdown.
[^extensions]: GitHub Flavored Markdown (GFM), CommonMark, and markdown-it are representative extended specifications.

## Long Footnotes

SkimDown's rendering pipeline consists of multiple steps[^pipeline].

[^pipeline]: Rendering pipeline details:

    1. Parse Markdown text to HTML with markdown-it
    2. Sanitize HTML with DOMPurify
    3. Normalize task list checkboxes
    4. Resolve link and image paths
    5. Wrap tables in scrollable containers
    6. Render Mermaid blocks as diagrams
    7. Add toolbars (language label + copy button) to code blocks
    8. Render math with KaTeX

    This involves multiple post-processing steps.

## Inline Footnotes

Inline footnotes are also supported^[This is an inline footnote. No need to define it separately.].

Another example^[SkimDown is a read-only viewer, so it does not have Markdown editing features.].

## Multiple References

You can reference the same footnote from multiple locations. SkimDown[^1] is an app for macOS. It uses markdown-it[^1] to render Markdown.
