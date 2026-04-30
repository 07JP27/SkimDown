# Copilot instructions for SkimDown

SkimDown is a Swift 6 AppKit macOS app. Follow the architecture in `design/ARCHITECTURE.md`: keep application startup in `App`, persistence and folder access in `Core`, tree UI in `Sidebar`, Markdown discovery/rendering helpers in `Markdown`, `WKWebView` integration in `Viewer`, shared types in `Models`, and URL/path helpers in `Utilities`.

Prioritize read-only behavior and clear folder-boundary checks. Do not add editing, export, print, cross-file search, file-name search, AI-service calls, or a dedicated Settings window unless the design changes.

