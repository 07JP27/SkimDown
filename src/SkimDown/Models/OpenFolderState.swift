import Foundation
import CoreGraphics

/// Persisted state for a single open folder window: the folder bookmark,
/// the on-screen frame, and the sidebar width the window had when last
/// persisted, so that windows can be restored at the same position, size,
/// and sidebar layout on next launch.
struct OpenFolderState: Equatable {
    let bookmark: Data
    let frame: CGRect
    let sidebarWidth: Double

    private enum DictionaryKey {
        static let bookmark = "bookmark"
        static let frame = "frame"
        static let sidebarWidth = "sidebarWidth"
    }

    var dictionaryRepresentation: [String: Any] {
        [
            DictionaryKey.bookmark: bookmark,
            DictionaryKey.frame: Self.encode(frame: frame),
            DictionaryKey.sidebarWidth: sidebarWidth
        ]
    }

    init(bookmark: Data, frame: CGRect, sidebarWidth: Double = 0) {
        self.bookmark = bookmark
        self.frame = frame
        self.sidebarWidth = sidebarWidth
    }

    init?(dictionary: [String: Any]) {
        guard let bookmark = dictionary[DictionaryKey.bookmark] as? Data else {
            return nil
        }
        let frame: CGRect
        if let frameString = dictionary[DictionaryKey.frame] as? String,
           let decoded = Self.decode(frameString: frameString) {
            frame = decoded
        } else {
            frame = .zero
        }
        self.bookmark = bookmark
        self.frame = frame
        self.sidebarWidth = dictionary[DictionaryKey.sidebarWidth] as? Double ?? 0
    }

    private static func encode(frame: CGRect) -> String {
        "\(frame.origin.x),\(frame.origin.y),\(frame.size.width),\(frame.size.height)"
    }

    private static func decode(frameString: String) -> CGRect? {
        let parts = frameString.split(separator: ",")
        guard parts.count == 4,
              let x = Double(parts[0]),
              let y = Double(parts[1]),
              let w = Double(parts[2]),
              let h = Double(parts[3]) else {
            return nil
        }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

