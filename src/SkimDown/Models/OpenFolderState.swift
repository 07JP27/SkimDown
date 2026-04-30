import Foundation
import CoreGraphics

/// Persisted state for a single open folder window: the folder bookmark and
/// the on-screen frame the window had when last persisted, so that windows
/// can be restored at the same position and size on next launch.
struct OpenFolderState: Equatable {
    let bookmark: Data
    let frame: CGRect

    private enum DictionaryKey {
        static let bookmark = "bookmark"
        static let frame = "frame"
    }

    var dictionaryRepresentation: [String: Any] {
        [
            DictionaryKey.bookmark: bookmark,
            DictionaryKey.frame: Self.encode(frame: frame)
        ]
    }

    init(bookmark: Data, frame: CGRect) {
        self.bookmark = bookmark
        self.frame = frame
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

