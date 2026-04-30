import Foundation

enum SecurityScopedBookmarkError: LocalizedError {
    case staleBookmark

    var errorDescription: String? {
        switch self {
        case .staleBookmark:
            return "Folder permission needs to be refreshed."
        }
    }
}

final class SecurityScopedAccess {
    let url: URL
    private var isAccessing: Bool

    init(url: URL) {
        let standardizedURL = url.standardizedFileURL
        self.url = standardizedURL
        self.isAccessing = standardizedURL.startAccessingSecurityScopedResource()
    }

    func stop() {
        if isAccessing {
            url.stopAccessingSecurityScopedResource()
            isAccessing = false
        }
    }

    deinit {
        stop()
    }
}

final class SecurityScopedBookmarkStore {
    func bookmarkData(for folderURL: URL) throws -> Data {
        try folderURL.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func resolveBookmarkData(_ data: Data) throws -> (url: URL, access: SecurityScopedAccess) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        guard !isStale else {
            throw SecurityScopedBookmarkError.staleBookmark
        }

        let standardizedURL = url.standardizedFileURL
        return (standardizedURL, SecurityScopedAccess(url: standardizedURL))
    }
}

