import AppKit

extension NSPasteboard {
    var skimdownFolderURL: URL? {
        guard let urls = readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else {
            return nil
        }

        return urls.first { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }
}