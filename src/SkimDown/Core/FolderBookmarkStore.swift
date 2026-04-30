import Foundation

enum FolderBookmarkError: LocalizedError {
    case staleBookmark

    var errorDescription: String? {
        switch self {
        case .staleBookmark:
            return "Folder location needs to be refreshed."
        }
    }
}

/// Resolves and creates plain (non security-scoped) URL bookmarks for folders.
///
/// SkimDown is distributed as a standard, non-sandboxed macOS app, so we use
/// regular bookmarks here. They still gracefully follow folder moves and
/// renames, which is what powers the Recent Folders menu and last-folder
/// restore on launch.
final class FolderBookmarkStore {
    func bookmarkData(for folderURL: URL) throws -> Data {
        try folderURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func resolveBookmarkData(_ data: Data) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        guard !isStale else {
            throw FolderBookmarkError.staleBookmark
        }

        return url.standardizedFileURL
    }
}
