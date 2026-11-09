import XCTest
@testable import OpenspotCore

final class ActionMenuTests: XCTestCase {
    private let paste = CommandAction(id: "paste", title: "Paste", key: ActionKey(text: "cmd+return"))
    private let delete = CommandAction(id: "delete", title: "Delete", confirm: "Delete this?")
    private let new = CommandAction(id: "new", title: "New", scope: .command, isForm: true)
    private let item = SpotItem(title: "One", run: "1")

    private func command(kind: SpotKind = .list, primary: String? = "Copy") -> Spot {
        Spot(id: "a/A", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: kind, primary: primary, actions: [paste, delete, new])
    }

    private func long() throws -> ActionMenu {
        let actions = ["Open in Zed", "Open in Cursor", "Use Zed by default", "Use Cursor by default", "Show in Finder"].enumerated().map {
            CommandAction(id: "a\($0.offset)", title: $0.element)
        } + [CommandAction(id: "copy", title: "Copy path", key: ActionKey(text: "cmd+shift+c"))]
        return try XCTUnwrap(ActionMenu(command: Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .list, primary: "Open", actions: actions), item: item))
    }

    func testAMenuOfMoreThanFiveRowsFindsRowsByTheirWords() throws {
        var menu = try long()
        menu.move(by: 2)

        menu.search("zed")

        XCTAssertTrue(menu.isSearchable)
        XCTAssertEqual(menu.shown.map(\.title), ["Open in Zed", "Use Zed by default"])
        XCTAssertEqual(menu.lines, 3)
        XCTAssertEqual(menu.selectedRow?.title, "Open in Zed")
        menu.move(by: 1)
        XCTAssertEqual(menu.press()?.title, "Use Zed by default")
        menu.search("nothing")
        XCTAssertNil(menu.press())
        XCTAssertEqual(menu.lines, 1)
    }

    func testTheKeyOfAnActionThatTheSearchHidesStillSelectsIt() throws {
        var menu = try long()
        menu.search("zed")

        menu.select(try XCTUnwrap(menu.rows.last?.action))

        XCTAssertEqual(menu.query, "")
        XCTAssertEqual(menu.selectedRow?.title, "Copy path")
    }

    func testAMenuOfFiveRowsHasNoSearch() throws {
        let menu = try XCTUnwrap(ActionMenu(command: command(), item: item))

        XCTAssertFalse(menu.isSearchable)
        XCTAssertEqual(menu.lines, 4)
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

    func testAMenuThatOffersSharingEndsWithIt() throws {
        let menu = try XCTUnwrap(ActionMenu(command: command(), item: nil, extras: [.share, .remove()]))

        XCTAssertEqual(menu.rows.map(\.title), ["Open", "New", "Copy to share", "Delete"])
        XCTAssertEqual(menu.rows[2].action, .share)
    }

    func testAMenuWithOnlySharingStillOpens() throws {
        let slider = Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .slider)

        XCTAssertNil(ActionMenu(command: slider, item: nil))
        XCTAssertEqual(ActionMenu(command: slider, item: nil, extras: [.share])?.rows.map(\.title), ["Copy to share"])
    }

    func testRemoveAsksForASecondPress() throws {
        var menu = try XCTUnwrap(ActionMenu(command: command(), item: nil, extras: [.remove()]))
        menu.select(.remove())

        XCTAssertNil(menu.press())
        XCTAssertEqual(menu.title(of: menu.rows[menu.selected]), "Press again to delete")
        XCTAssertEqual(menu.press()?.action, .remove())
    }

    func testTheRowsOfTheAppStayOutOfTheHint() throws {
        let plain = Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .list)

        XCTAssertEqual(ActionMenu(command: plain, item: nil, extras: [.share, .remove()])?.hint, "⏎ Open   ⌘K Actions")
    }

    func testRemoveNamesEachWidgetThatItTakesWithIt() {
        XCTAssertEqual(CommandAction.remove(widgets: 3).confirm, "Press again to delete 3 widgets")
    }

    func testAMoveToTheSameRowKeepsItsQuestion() throws {
        var menu = try XCTUnwrap(ActionMenu(command: command(), item: nil, extras: [.remove()]))
        menu.select(.remove())
        XCTAssertNil(menu.press())

        menu.move(by: 0)

        XCTAssertEqual(menu.press()?.action, .remove())
    }

    func testWithNoItemOnlyTheCommandsActionsShow() throws {
        let menu = try XCTUnwrap(ActionMenu(command: command(), item: nil))

        XCTAssertEqual(menu.rows.map(\.title), ["Open", "New"])
    }

    func testTheHintAlsoNamesAnActionThatHoldsEscape() throws {
        let cancel = CommandAction(id: "cancel", title: "Cancel", key: ActionKey(text: "escape"), scope: .command)
        let trash = CommandAction(id: "remove", title: "Move to Trash", key: ActionKey(text: "cmd+return"), scope: .command)
        let sheet = Spot(id: "apps", name: "Apps", url: URL(fileURLWithPath: "/bin/true"), kind: .list, actions: [cancel, trash])

        XCTAssertEqual(ActionMenu(command: sheet, item: item)?.hint, "⏎ Open   ⌘⏎ Move to Trash   Esc Cancel   ⌘K Actions")
    }

    func testAKeyLabelOfTheFooterNamesItsKey() {
        XCTAssertEqual(ActionKey(label: "⌘⇧N"), ActionKey(name: "n", isCommand: true, isShift: true))
        XCTAssertEqual(ActionKey(label: "⌘⏎"), ActionKey(name: "return", isCommand: true))
        XCTAssertEqual(ActionKey(label: "⏎"), ActionKey(name: "return"))
        XCTAssertEqual(ActionKey(label: "↩"), ActionKey(name: "return"))
        XCTAssertEqual(ActionKey(label: "⌘⌫"), ActionKey(name: "backspace", isCommand: true))
        XCTAssertEqual(ActionKey(label: "Esc"), ActionKey(name: "escape"))
        XCTAssertEqual(ActionKey(label: "⌘K"), ActionKey(name: "k", isCommand: true))
        XCTAssertNil(ActionKey(label: "⇧"))
        for text in ["cmd+shift+n", "cmd+return", "escape", "cmd+backspace", "s"] {
            let key = ActionKey(text: text)
            XCTAssertEqual(key.flatMap { ActionKey(label: $0.label) }, key, text)
        }
    }

    func testAnOpenListWithNoSelectedItemLeavesOutOpen() throws {
        let menu = try XCTUnwrap(ActionMenu(command: command(), item: nil, showsPrimary: false))

        XCTAssertEqual(menu.rows.map(\.title), ["New"])
    }

    func testTheHintNamesTheFirstKeysAndTheMenu() throws {
        let keyed = Spot(id: "a/A", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .list, primary: "Copy", actions: [paste, delete, new])

        XCTAssertEqual(ActionMenu(command: keyed, item: item)?.hint, "⏎ Copy   ⌘⏎ Paste   ⌘K Actions")
        XCTAssertEqual(ActionMenu(command: keyed, item: nil, showsPrimary: false)?.hint, "⌘K Actions")
    }

    func testEachKindOfSpotSaysWhatEnterDoes() {
        XCTAssertEqual(command(kind: .launch).primaryTitle(hasItem: false), "Run")
        XCTAssertEqual(command(kind: .toggle).primaryTitle(hasItem: false), "Toggle")
        XCTAssertEqual(command(kind: .list).primaryTitle(hasItem: false), "Open")
        XCTAssertNil(command(kind: .slider).primaryTitle(hasItem: false))
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
        let keyed = Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .launch, actions: [
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
        let asking = Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .launch, actions: [
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
