import Foundation

/// Git change state of a working-tree file compared with `HEAD`.
enum GitFileStatus: String, Sendable {
    /// Tracked in `HEAD` with different contents.
    case modified
    /// Not in `HEAD` or the index, and not ignored.
    case untracked
    /// Not in `HEAD` but staged in the index.
    case added
}
