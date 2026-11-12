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
        return try XCTUnwrap(ActionMenu(spot: Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .list, primary: "Open", actions: actions), item: item))
    }

    func testALongMenuOpensOnItsFirstRow() throws {
        XCTAssertEqual(try long().selectedRow?.title, "Open")
    }

    func testAMenuOfMoreThanFiveRowsFindsRowsByTheirWords() throws {
        var menu = try long()
        menu.move(by: 2)

        menu.search("zed")

        XCTAssertTrue(menu.isSearchable)
        XCTAssertEqual(menu.shown.map(\.title), ["Open in Zed", "Use Zed by default"])
        XCTAssertEqual(menu.lines, 3)
        XCTAssertEqual(menu.fullLines, 8)
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

    func testAMenuOfThreeRowsSearchesAndAMenuOfTwoDoesNot() throws {
        let three = try XCTUnwrap(ActionMenu(spot: command(), item: item))
        let two = try XCTUnwrap(ActionMenu(
            spot: Spot(id: "b", name: "B", url: URL(fileURLWithPath: "/bin/true"), kind: .list, primary: "Copy", actions: [paste, delete]),
            item: item,
            showsPrimary: false
        ))

        XCTAssertTrue(three.isSearchable)
        XCTAssertEqual(three.lines, three.rows.count + 1)
        XCTAssertEqual(two.rows.count, 2)
        XCTAssertFalse(two.isSearchable)
        XCTAssertEqual(two.lines, 2)
    }

    func testEachRowOfAGridCardsMenuActsOnThatCard() throws {
        let menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, extras: [.share]))

        XCTAssertEqual(menu.rows.dropFirst().filter { $0.action == nil }.map(\.title), [])
        XCTAssertFalse(menu.rows.map(\.title).contains("Edit Spots"))
    }

    func testAnItemListsWhatEnterDoesThenEachAction() throws {
        let menu = try XCTUnwrap(ActionMenu(spot: command(), item: item))

        XCTAssertEqual(menu.rows.map(\.title), ["Copy", "Paste", "Delete", "New"])
        XCTAssertEqual(menu.rows.map(\.keyLabel), ["⏎", "⌘⏎", "", ""])
    }

    func testAnItemCanHideAnAction() throws {
        let menu = try XCTUnwrap(ActionMenu(spot: command(), item: SpotItem(title: "One", run: "1", hides: ["paste"])))

        XCTAssertEqual(menu.rows.map(\.title), ["Copy", "Delete", "New"])
    }

    func testAMenuThatOffersSharingEndsWithIt() throws {
        let menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, extras: [.share, .remove()]))

        XCTAssertEqual(menu.rows.map(\.title), ["Open", "New", "Share", "Delete"])
        XCTAssertEqual(menu.rows[2].action, .share)
    }

    func testAMenuWithOnlySharingStillOpens() throws {
        let slider = Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .slider)

        XCTAssertNil(ActionMenu(spot: slider, item: nil))
        XCTAssertEqual(ActionMenu(spot: slider, item: nil, extras: [.share])?.rows.map(\.title), ["Share"])
    }

    /// An action of a script that asks for a second press, such as a forget of a network.
    private let forget = CommandAction(id: "forget", title: "Forget", scope: .command, confirm: "Press again to forget")

    func testAnActionWithAConfirmAsksForASecondPress() throws {
        var menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, extras: [forget]))
        menu.select(forget)

        XCTAssertNil(menu.press())
        XCTAssertEqual(menu.title(of: menu.rows[menu.selected]), "Press again to forget")
        XCTAssertEqual(menu.press()?.action, forget)
    }

    func testDeleteAsksForNoSecondPressBecauseUndoTakesItBack() {
        XCTAssertNil(CommandAction.remove().confirm)
        XCTAssertNil(CommandAction.remove(widgets: 3).confirm)
    }

    func testTheRowsOfTheAppStayOutOfTheHint() throws {
        let plain = Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .list)

        XCTAssertEqual(ActionMenu(spot: plain, item: nil, extras: [.share, .remove()])?.hint, "⏎ Open   ⌘K Actions")
    }

    func testAMoveToTheSameRowKeepsItsQuestion() throws {
        var menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, extras: [forget]))
        menu.select(forget)
        XCTAssertNil(menu.press())

        menu.move(by: 0)

        XCTAssertEqual(menu.press()?.action, forget)
    }

    func testWithNoItemOnlyTheCommandsActionsShow() throws {
        let menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil))

        XCTAssertEqual(menu.rows.map(\.title), ["Open", "New"])
    }

    func testTheHintAlsoNamesAnActionThatHoldsEscape() throws {
        let cancel = CommandAction(id: "cancel", title: "Cancel", key: ActionKey(text: "escape"), scope: .command)
        let trash = CommandAction(id: "remove", title: "Move to Trash", key: ActionKey(text: "cmd+return"), scope: .command)
        let sheet = Spot(id: "apps", name: "Apps", url: URL(fileURLWithPath: "/bin/true"), kind: .list, actions: [cancel, trash])

        XCTAssertEqual(ActionMenu(spot: sheet, item: item)?.hint, "⏎ Open   ⌘⏎ Move to Trash   Esc Cancel   ⌘K Actions")
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
        let menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, showsPrimary: false))

        XCTAssertEqual(menu.rows.map(\.title), ["New"])
    }

    func testTheHintNamesTheFirstKeysAndTheMenu() throws {
        let keyed = Spot(id: "a/A", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .list, primary: "Copy", actions: [paste, delete, new])

        XCTAssertEqual(ActionMenu(spot: keyed, item: item)?.hint, "⏎ Copy   ⌘⏎ Paste   ⌘K Actions")
        XCTAssertEqual(ActionMenu(spot: keyed, item: nil, showsPrimary: false)?.hint, "⌘K Actions")
    }

    func testEachKindOfSpotSaysWhatEnterDoes() {
        XCTAssertEqual(command(kind: .launch).primaryTitle(hasItem: false), "Run")
        XCTAssertEqual(command(kind: .toggle).primaryTitle(hasItem: false), "Toggle")
        XCTAssertEqual(command(kind: .list).primaryTitle(hasItem: false), "Open")
        XCTAssertNil(command(kind: .slider).primaryTitle(hasItem: false))
    }

    func testAnActionThatConfirmsNeedsASecondPress() throws {
        var menu = try XCTUnwrap(ActionMenu(spot: command(), item: item))
        menu.select(delete)

        XCTAssertNil(menu.press())
        XCTAssertEqual(menu.title(of: menu.rows[menu.selected]), "Delete this?")
        XCTAssertEqual(menu.press()?.action, delete)
    }

    func testMovingAwayCancelsTheConfirm() throws {
        var menu = try XCTUnwrap(ActionMenu(spot: command(), item: item))
        menu.select(delete)
        _ = menu.press()

        menu.move(by: -1)
        menu.move(by: 1)

        XCTAssertNil(menu.press())
    }

    func testMovingStopsAtEachEnd() throws {
        var menu = try XCTUnwrap(ActionMenu(spot: command(), item: item))

        menu.move(by: -3)
        XCTAssertEqual(menu.selected, 0)
        menu.move(by: 30)
        XCTAssertEqual(menu.selected, 3)
    }

    func testARunningRowSaysThatItsPressStopsTheCall() throws {
        let keyed = Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .launch, actions: [
            CommandAction(id: "copy", title: "Copy", key: ActionKey(text: "cmd+c"), scope: .command)
        ])
        let menu = try XCTUnwrap(ActionMenu(spot: keyed, item: nil))
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
        var menu = try XCTUnwrap(ActionMenu(spot: asking, item: nil, showsPrimary: false))

        XCTAssertEqual(menu.press(isRunning: true)?.action?.id, "wipe")
        XCTAssertNil(menu.confirming)
        XCTAssertNil(menu.press())
        XCTAssertEqual(menu.title(of: menu.rows[0]), "Wipe all?")
        XCTAssertEqual(menu.title(of: menu.rows[0], isRunning: true), "Stop Wipe")
    }
}
