import XCTest
@testable import SkimDown

final class GitTreeDecorationTests: XCTestCase {
    func testFolderStatusesAggregateChildrenByPriority() {
        let statuses = GitTreeDecoration.folderStatuses(for: [
            "root.md": .modified,
            "docs/a.md": .untracked,
            "docs/guide/b.md": .modified,
            "notes/c.md": .untracked,
            "notes/d.md": .added
        ])

        XCTAssertEqual(statuses, [
            "docs": .modified,
            "docs/guide": .modified,
            "notes": .added
        ])
    }

    func testBadges() {
        XCTAssertEqual(GitTreeDecoration.badge(for: .modified), "M")
        XCTAssertEqual(GitTreeDecoration.badge(for: .untracked), "U")
        XCTAssertEqual(GitTreeDecoration.badge(for: .added), "A")
    }
}
