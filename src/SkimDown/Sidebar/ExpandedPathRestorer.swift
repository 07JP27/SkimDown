import Foundation

enum ExpandedPathRestorer {
    /// Returns the directory items that should be expanded, in parent-before-child order.
    ///
    /// The order matters: `NSOutlineView.expandItem(_:)` only expands an item once its
    /// parent is expanded, so callers must expand ancestors first. This function
    /// performs a depth-first pre-order traversal and only emits items whose
    /// `relativePath` is in `desired`. It is a pure function — it never mutates
    /// the input or `desired`, which keeps callers safe even when expansion
    /// triggers downstream notifications that would otherwise mutate shared state.
    static func pathsToExpand(in items: [MarkdownTreeItem], desired: Set<String>) -> [MarkdownTreeItem] {
        guard !desired.isEmpty else {
            return []
        }
        var result: [MarkdownTreeItem] = []
        for item in items {
            collect(item, desired: desired, into: &result)
        }
        return result
    }

    private static func collect(_ item: MarkdownTreeItem, desired: Set<String>, into result: inout [MarkdownTreeItem]) {
        if item.isDirectory, desired.contains(item.relativePath) {
            result.append(item)
        }
        for child in item.children {
            collect(child, desired: desired, into: &result)
        }
    }
}
