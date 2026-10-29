import Foundation

/// A contiguous run of changed lines. Line numbers are 0-based.
struct LineDiffHunk: Equatable, Sendable {
    let newStart: Int
    let newCount: Int
    let oldStart: Int
    let oldCount: Int
    let oldLines: [String]
}

enum LineDiff {
    /// Splits text into lines after removing a UTF-8 BOM and normalizing CRLF / CR to LF.
    /// A trailing newline does not produce an extra empty line.
    static func lines(in text: String) -> [String] {
        var normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if normalized.hasPrefix("\u{FEFF}") {
            normalized.removeFirst()
        }
        guard !normalized.isEmpty else {
            return []
        }

        var lines = normalized.components(separatedBy: "\n")
        if normalized.hasSuffix("\n") {
            lines.removeLast()
        }
        return lines
    }

    static func hunks(old: String, new: String) -> [LineDiffHunk] {
        let oldLines = lines(in: old)
        let newLines = lines(in: new)
        let difference = newLines.difference(from: oldLines)
        guard !difference.isEmpty else {
            return []
        }

        var removedOffsets = Set<Int>()
        var insertedOffsets = Set<Int>()
        for change in difference {
            switch change {
            case .remove(let offset, _, _):
                removedOffsets.insert(offset)
            case .insert(let offset, _, _):
                insertedOffsets.insert(offset)
            }
        }

        var hunks: [LineDiffHunk] = []
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < oldLines.count || newIndex < newLines.count {
            guard removedOffsets.contains(oldIndex) || insertedOffsets.contains(newIndex) else {
                oldIndex += 1
                newIndex += 1
                continue
            }

            let oldStart = oldIndex
            let newStart = newIndex
            while removedOffsets.contains(oldIndex) || insertedOffsets.contains(newIndex) {
                while removedOffsets.contains(oldIndex) {
                    oldIndex += 1
                }
                while insertedOffsets.contains(newIndex) {
                    newIndex += 1
                }
            }
            hunks.append(LineDiffHunk(
                newStart: newStart,
                newCount: newIndex - newStart,
                oldStart: oldStart,
                oldCount: oldIndex - oldStart,
                oldLines: Array(oldLines[oldStart..<oldIndex])
            ))
        }
        return hunks
    }
}
