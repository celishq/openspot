import XCTest
@testable import OpenspotCore

final class ActionMenuTests: XCTestCase {
    private let paste = CommandAction(id: "paste", title: "Paste", key: ActionKey(text: "cmd+return"))
    private let delete = CommandAction(id: "delete", title: "Delete", confirm: "Delete this?")
    private let new = CommandAction(id: "new", title: "New", scope: .command, isForm: true)
    private let item = SpotItem(title: "One", run: "1")

    private func command(kind: SpotKind = .list, primary: String? = "Copy") -> PluginCommand {
        PluginCommand(id: "a/A", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: kind, primary: primary, actions: [paste, delete, new])
    }

    func testAnItemListsWhatEnterDoesThenEachAction() throws {
        let menu = try XCTUnwrap(ActionMenu(command: command(), item: item))

        XCTAssertEqual(menu.rows.map(\.title), ["Copy", "Paste", "Delete", "New"])
        XCTAssertEqual(menu.rows.map(\.keyLabel), ["⏎", "⌘⏎", "", ""])
    }

    func testWithNoItemOnlyTheCommandsActionsShow() throws {
        let menu = try XCTUnwrap(ActionMenu(command: command(), item: nil))

        XCTAssertEqual(menu.rows.map(\.title), ["Open", "New"])
    }

    func testAnOpenListWithNoSelectedItemLeavesOutOpen() throws {
        let menu = try XCTUnwrap(ActionMenu(command: command(), item: nil, showsPrimary: false))

        XCTAssertEqual(menu.rows.map(\.title), ["New"])
    }

    func testTheHintNamesTheFirstKeysAndTheMenu() throws {
        let keyed = PluginCommand(id: "a/A", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .list, primary: "Copy", actions: [paste, delete, new])

        XCTAssertEqual(ActionMenu(command: keyed, item: item)?.hint, "⏎ Copy   ⌘⏎ Paste   ⌘K Actions")
        XCTAssertEqual(ActionMenu(command: keyed, item: nil, showsPrimary: false)?.hint, "⌘K Actions")
    }

    func testEachKindOfSpotSaysWhatEnterDoes() {
        XCTAssertEqual(command(kind: .launch).primaryTitle(hasItem: false), "Run")
        XCTAssertEqual(command(kind: .toggle).primaryTitle(hasItem: false), "Toggle")
        XCTAssertEqual(command(kind: .list).primaryTitle(hasItem: false), "Open")
        XCTAssertNil(command(kind: .slider).primaryTitle(hasItem: false))
    }

    func testASliderWithNoActionsHasNoMenu() {
        let slider = PluginCommand(id: "a/A", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .slider)

        XCTAssertNil(ActionMenu(command: slider, item: nil))
    }

    func testAnActionThatConfirmsNeedsASecondPress() throws {
        var menu = try XCTUnwrap(ActionMenu(command: command(), item: item))
        menu.select(delete)

        XCTAssertNil(menu.press())
        XCTAssertEqual(menu.title(of: menu.rows[menu.selected]), "Delete this?")
        XCTAssertEqual(menu.press()?.action, delete)
    }

    func testMovingAwayCancelsTheConfirm() throws {
        var menu = try XCTUnwrap(ActionMenu(command: command(), item: item))
        menu.select(delete)
        _ = menu.press()

        menu.move(by: -1)
        menu.move(by: 1)

        XCTAssertNil(menu.press())
    }

    func testMovingStopsAtEachEnd() throws {
        var menu = try XCTUnwrap(ActionMenu(command: command(), item: item))

        menu.move(by: -3)
        XCTAssertEqual(menu.selected, 0)
        menu.move(by: 30)
        XCTAssertEqual(menu.selected, 3)
    }
}
