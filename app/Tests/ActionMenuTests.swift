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

    func testAGridCardOffersToEditTheSpotsAfterItsActions() throws {
        let menu = try XCTUnwrap(ActionMenu(command: command(), item: nil, showsEdit: true))

        XCTAssertEqual(menu.rows.last?.title, "Edit Spots")
        XCTAssertEqual(menu.rows.last?.opensEdit, true)
        XCTAssertFalse(menu.hint.contains("Edit Spots"))
    }

    func testAnItemListsWhatEnterDoesThenEachAction() throws {
        let menu = try XCTUnwrap(ActionMenu(command: command(), item: item))

        XCTAssertEqual(menu.rows.map(\.title), ["Copy", "Paste", "Delete", "New"])
        XCTAssertEqual(menu.rows.map(\.keyLabel), ["⏎", "⌘⏎", "", ""])
    }

    func testAnItemCanHideAnAction() throws {
        let menu = try XCTUnwrap(ActionMenu(command: command(), item: SpotItem(title: "One", run: "1", hides: ["paste"])))

        XCTAssertEqual(menu.rows.map(\.title), ["Copy", "Delete", "New"])
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

    func testARunningRowSaysThatItsPressStopsTheCall() throws {
        let keyed = PluginCommand(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .launch, actions: [
            CommandAction(id: "copy", title: "Copy", key: ActionKey(text: "cmd+c"), scope: .command)
        ])
        let menu = try XCTUnwrap(ActionMenu(command: keyed, item: nil))
        let primary = menu.rows[0]
        let copy = menu.rows[1]

        XCTAssertEqual(menu.title(of: primary), "Run")
        XCTAssertEqual(menu.title(of: primary, isRunning: true), "Stop")
        XCTAssertEqual(menu.title(of: copy, isRunning: true), "Stop Copy")
        XCTAssertEqual(menu.hint(stopping: { $0.action == nil }), "⏎ Stop   ⌘C Copy   ⌘K Actions")
        XCTAssertEqual(menu.hint(stopping: { $0.action != nil }), "⏎ Run   ⌘C Stop Copy   ⌘K Actions")
        XCTAssertEqual(menu.hint(stopping: { _ in false }), menu.hint)
    }

    func testAPressOfARunningRowStopsWithNoQuestion() throws {
        let asking = PluginCommand(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .launch, actions: [
            CommandAction(id: "wipe", title: "Wipe", scope: .command, confirm: "Wipe all?")
        ])
        var menu = try XCTUnwrap(ActionMenu(command: asking, item: nil, showsPrimary: false))

        XCTAssertEqual(menu.press(isRunning: true)?.action?.id, "wipe")
        XCTAssertNil(menu.confirming)
        XCTAssertNil(menu.press())
        XCTAssertEqual(menu.title(of: menu.rows[0]), "Wipe all?")
        XCTAssertEqual(menu.title(of: menu.rows[0], isRunning: true), "Stop Wipe")
    }
}
