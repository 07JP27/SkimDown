import Foundation

final class TemporaryFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkimDownTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func write(_ string: String, to relativePath: String) throws {
        let fileURL = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = string.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: fileURL)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

