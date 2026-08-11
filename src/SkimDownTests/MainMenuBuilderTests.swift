import AppKit
import XCTest
@testable import SkimDown

@MainActor
final class MainMenuBuilderTests: XCTestCase {
    func testToggleSidebarUsesCommandBShortcut() throws {
        let menu = MainMenuBuilder.build(target: AppDelegate())
        let viewMenu = try XCTUnwrap(menu.items.first { $0.submenu?.title == "View" }?.submenu)
        let toggleSidebar = try XCTUnwrap(viewMenu.item(withTitle: "Toggle Sidebar"))

        XCTAssertEqual(toggleSidebar.keyEquivalent, "b")
        XCTAssertTrue(toggleSidebar.keyEquivalentModifierMask.contains(.command))
        XCTAssertFalse(toggleSidebar.keyEquivalentModifierMask.contains(.shift))
        XCTAssertFalse(toggleSidebar.keyEquivalentModifierMask.contains(.option))
        XCTAssertFalse(toggleSidebar.keyEquivalentModifierMask.contains(.control))
    }
}
