# Product

## Register

product

## Users

SkimDown is for people reviewing Markdown folders produced by AI agents, developer tools, and teams. They are usually skimming specs, READMEs, notes, logs, and generated documentation locally on macOS, moving between a file tree and a rendered preview without wanting an editor workspace around them.

## Product Purpose

SkimDown turns a selected folder of Markdown files into a calm, read-only reading surface. Success means users can open a folder, scan the Markdown tree, read the selected file beautifully, search within the current document, follow safe links, and trust that the app will not modify files or send Markdown content outside the machine.

## Brand Personality

Quiet, native, trustworthy. The product should feel like transparent paper on macOS: light, focused, and polished without becoming decorative or competing with the reading surface.

## Anti-references

SkimDown should not look or behave like a full Markdown editor, a heavyweight document-management workspace, Postman, Notion, or a generic AI dashboard. It should avoid editor chrome, save/export/print affordances, multi-file search, AI-service calls, and visual treatments that make supporting UI louder than the document.

## Design Principles

- Keep reading primary: navigation and controls should support the document without competing with it.
- Stay read-only and local-first: reinforce trust by avoiding accidental edits, broad file access, or external transmission of Markdown content.
- Use native macOS behavior: prefer AppKit conventions, menu-driven actions, and subtle system-aligned feedback over custom chrome.
- Respect folder boundaries: every navigation and resource decision should preserve the selected-folder security model.
- Polish through restraint: use spacing, typography, and contrast rather than heavy decoration.

## Accessibility & Inclusion

Use native macOS accessibility behavior where possible, maintain sufficient text contrast in light and dark themes, preserve keyboard/menu access for core actions, and respect reduced-motion expectations for any future animated UI. No separate WCAG target is documented in the repository today.
