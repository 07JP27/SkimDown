# Privacy & Permissions

SkimDown is a local, read-only Markdown viewer. It is designed to read the folder you choose, not to manage or modify your files.

## Folder access

SkimDown asks you to choose a folder with the macOS folder picker. It only reads folders that you select.

Recent and previous folders can reopen because SkimDown stores macOS security-scoped access for those selected folders.

## Read-only behavior

SkimDown does not edit, save, export, print, or modify Markdown files. It is built for reading and navigation only.

## Local file boundaries

Relative Markdown links and local images are resolved only when the target stays inside the folder you opened. SkimDown does not use a Markdown file to browse arbitrary local files outside that folder.

## Sanitized HTML

Embedded HTML is sanitized before display. Unsafe tags, event attributes, and dangerous URL schemes are removed.

## External content

External links open in your default browser. External images referenced by Markdown may be loaded in the preview.

## No external transmission

SkimDown does not send your Markdown text or folder contents to external services. External links open in your browser, and externally hosted images may be requested by the preview as described above.
