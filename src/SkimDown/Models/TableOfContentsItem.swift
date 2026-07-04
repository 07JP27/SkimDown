import Foundation

struct TableOfContentsItem: Equatable, Hashable {
    let level: Int
    let title: String
    let id: String

    init(level: Int, title: String, id: String) {
        self.level = level
        self.title = title
        self.id = id
    }

    init?(javaScriptDictionary dictionary: [String: Any]) {
        guard let level = Self.intValue(dictionary["level"]),
              (1...6).contains(level),
              let title = dictionary["title"] as? String,
              let id = dictionary["id"] as? String,
              !id.isEmpty else {
            return nil
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return nil
        }

        self.level = level
        self.title = trimmedTitle
        self.id = id
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }
}
