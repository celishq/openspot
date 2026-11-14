import XCTest
@testable import OpenspotCore

final class ActionMenuTests: XCTestCase {
    private let paste = CommandAction(id: "paste", title: "Paste", key: ActionKey(text: "cmd+return"))
    private let delete = CommandAction(id: "delete", title: "Delete", confirm: "Delete this?")
    private let new = CommandAction(id: "new", title: "New", scope: .spot, isForm: true)
    private let item = SpotItem(title: "One", run: "1")
    private let share = CommandAction(id: "share", title: "Share", key: ActionKey(text: "cmd+shift+c"), scope: .spot, after: .close)
    private let delete2 = CommandAction(id: "delete", title: "Delete", key: ActionKey(text: "cmd+backspace"), scope: .spot)

    /// The actions of the app's spot, as it offers them to a card.
    private func app(_ actions: CommandAction...) -> [OfferedAction] {
        actions.map { OfferedAction(action: $0, owner: "openspot/actions") }
    }

    private func command(kind: SpotKind = .list, openTitle: String? = "Copy") -> Spot {
        Spot(id: "a/A", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: kind, openTitle: openTitle, actions: [paste, delete, new])
    }

    private func long() throws -> ActionMenu {
        let actions = ["Open in Zed", "Open in Cursor", "Use Zed by default", "Use Cursor by default", "Show in Finder"].enumerated().map {
            CommandAction(id: "a\($0.offset)", title: $0.element)
        } + [CommandAction(id: "copy", title: "Copy path", key: ActionKey(text: "cmd+shift+c"))]
        return try XCTUnwrap(ActionMenu(spot: Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .list, openTitle: "Open", actions: actions), item: item))
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
            spot: Spot(id: "b", name: "B", url: URL(fileURLWithPath: "/bin/true"), kind: .list, openTitle: "Copy", actions: [paste, delete]),
            item: item,
            showsOpen: false
        ))

        XCTAssertTrue(three.isSearchable)
        XCTAssertEqual(three.lines, three.rows.count + 1)
        XCTAssertEqual(two.rows.count, 2)
        XCTAssertFalse(two.isSearchable)
        XCTAssertEqual(two.lines, 2)
    }

    func test_A28_eachRowOfAGridCardsMenuActsOnThatCard() throws {
        let menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, offered: app(share)))

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
        let menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, offered: app(share, delete2)))

        XCTAssertEqual(menu.rows.map(\.title), ["Open", "New", "Share", "Delete"])
        XCTAssertEqual(menu.rows[2].action, share)
        XCTAssertEqual(menu.rows[2].owner, "openspot/actions")
    }

    func testAMenuWithOnlySharingStillOpens() throws {
        let slider = Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .slider)

        XCTAssertNil(ActionMenu(spot: slider, item: nil))
        XCTAssertEqual(ActionMenu(spot: slider, item: nil, offered: app(share))?.rows.map(\.title), ["Share"])
    }

    /// An action of a script that asks for a second press, such as a forget of a network.
    private let forget = CommandAction(id: "forget", title: "Forget", scope: .spot, confirm: "Press again to forget")

    func testAnActionWithAConfirmAsksForASecondPress() throws {
        var menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, offered: app(forget)))
        menu.select(forget)

        XCTAssertNil(menu.press())
        XCTAssertEqual(menu.title(of: menu.rows[menu.selected]), "Press again to forget")
        XCTAssertEqual(menu.press()?.action, forget)
    }

    func testTheRowsOfTheAppStayOutOfTheHint() throws {
        let plain = Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .list)

        XCTAssertEqual(ActionMenu(spot: plain, item: nil, offered: app(share, delete2))?.hint, "⏎ Open   ⌘K Actions")
    }

    func testAMoveToTheSameRowKeepsItsQuestion() throws {
        var menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, offered: app(forget)))
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
        let cancel = CommandAction(id: "cancel", title: "Cancel", key: ActionKey(text: "escape"), scope: .spot)
        let trash = CommandAction(id: "remove", title: "Move to Trash", key: ActionKey(text: "cmd+return"), scope: .spot)
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
        let menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, showsOpen: false))

        XCTAssertEqual(menu.rows.map(\.title), ["New"])
    }

    func testTheHintNamesTheFirstKeysAndTheMenu() throws {
        let keyed = Spot(id: "a/A", name: "A", url: URL(fileURLWithPath: "/bin/true"), kind: .list, openTitle: "Copy", actions: [paste, delete, new])

        XCTAssertEqual(ActionMenu(spot: keyed, item: item)?.hint, "⏎ Copy   ⌘⏎ Paste   ⌘K Actions")
        XCTAssertEqual(ActionMenu(spot: keyed, item: nil, showsOpen: false)?.hint, "⌘K Actions")
    }

    func testEachKindOfSpotSaysWhatEnterDoes() {
        XCTAssertEqual(command(kind: .launch).openTitle(hasItem: false), "Run")
        XCTAssertEqual(command(kind: .toggle).openTitle(hasItem: false), "Toggle")
        XCTAssertEqual(command(kind: .list).openTitle(hasItem: false), "Open")
        XCTAssertNil(command(kind: .slider).openTitle(hasItem: false))
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
            CommandAction(id: "copy", title: "Copy", key: ActionKey(text: "cmd+c"), scope: .spot)
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
            CommandAction(id: "wipe", title: "Wipe", scope: .spot, confirm: "Wipe all?")
        ])
        var menu = try XCTUnwrap(ActionMenu(spot: asking, item: nil, showsOpen: false))

        XCTAssertEqual(menu.press(isRunning: true)?.action?.id, "wipe")
        XCTAssertNil(menu.confirming)
        XCTAssertNil(menu.press())
        XCTAssertEqual(menu.title(of: menu.rows[0]), "Wipe all?")
        XCTAssertEqual(menu.title(of: menu.rows[0], isRunning: true), "Stop Wipe")
    }

    func testOpenspotsActionsComeFirstWithNoHeaderThenEachOwnersGroupAToZWithAHeaderEach() throws {
        let icon = CommandAction(id: "change", title: "Change Icon", scope: .spot)
        let star = CommandAction(id: "star", title: "Star", scope: .spot)
        let edit = CommandAction(id: "edit", title: "Edit", scope: .spot)
        let menu = try XCTUnwrap(ActionMenu(
            spot: command(),
            item: nil,
            offered: [OfferedAction(action: star, owner: "z/Zoo", group: "Zoo"), OfferedAction(action: icon, owner: "i/Icon", group: "Icon")] + app(edit)
        ))

        XCTAssertEqual(menu.rows.map(\.title), ["Open", "New", "Edit", "Change Icon", "Star"])
        XCTAssertEqual(menu.rows.map(\.owner), [nil, nil, "openspot/actions", "i/Icon", "z/Zoo"])
        XCTAssertEqual(menu.headers, [ActionMenu.Header(title: "Icon", line: 3), ActionMenu.Header(title: "Zoo", line: 5)])
        XCTAssertEqual(menu.line(ofShown: 3), 4)
        XCTAssertEqual(menu.fullLines, 8)
    }

    func testASearchDropsTheHeadersAndAMenuOfOneGroupHasNone() throws {
        let icon = CommandAction(id: "change", title: "Change Icon", scope: .spot)
        var menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, offered: [OfferedAction(action: icon, owner: "i/Icon", group: "Icon")]))
        let bare = Spot(id: "b", name: "B", url: URL(fileURLWithPath: "/bin/true"))
        let alone = try XCTUnwrap(ActionMenu(spot: bare, item: nil, showsOpen: false, offered: [OfferedAction(action: icon, owner: "i/Icon", group: "Icon")]))

        menu.search("icon")

        XCTAssertEqual(menu.shown.map(\.title), ["Change Icon"])
        XCTAssertEqual(menu.headers, [])
        XCTAssertEqual(menu.line(ofShown: 0), 0)
        XCTAssertEqual(alone.rows.map(\.title), ["Change Icon"])
        XCTAssertEqual(alone.headers, [])
    }

    /// The Icon spot's Change Icon with its three children, by dot notation.
    private func icon() -> [OfferedAction] {
        [("change", "Change Icon"), ("change.draw", "Draw…"), ("change.file", "Choose File…"), ("change.reset", "Reset Icon")].map {
            OfferedAction(action: CommandAction(id: $0.0, title: $0.1, scope: .spot), owner: "openspot/icon")
        }
    }

    func testAnActionWhoseIDStartsWithAnotherOfItsSpotIsInItsSubmenu() throws {
        let menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, offered: icon()))

        XCTAssertEqual(menu.rows.map(\.title), ["Open", "New", "Change Icon"])
        XCTAssertEqual(menu.rows.last?.keyLabel, "›")
        XCTAssertEqual(menu.rows.last?.children.map(\.title), ["Draw…", "Choose File…", "Reset Icon"])
    }

    func testAPressOfARowWithChildrenOpensThemBesideItAndBackClosesThem() throws {
        var menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, offered: icon()))
        menu.move(by: 2)

        XCTAssertNil(menu.press())
        let top = menu.shown.map(\.title)
        let inside = menu.submenu?.rows.map(\.title)
        let parent = menu.parent?.title
        menu.move(by: 1)
        let file = menu.press()?.action?.id
        XCTAssertTrue(menu.back())

        XCTAssertEqual(top, ["Open", "New", "Change Icon"])
        XCTAssertEqual(inside, ["Draw…", "Choose File…", "Reset Icon"])
        XCTAssertEqual(parent, "Change Icon")
        XCTAssertEqual(file, "change.file")
        XCTAssertNil(menu.submenu)
        XCTAssertEqual(menu.selectedRow?.title, "Change Icon")
        XCTAssertFalse(menu.back())
    }

    func testThePointerOpensTheSubmenuOfItsRowAndClosesItOnAnotherRow() throws {
        var menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, offered: icon()))

        menu.point(at: 2)
        let opened = menu.submenu?.parent
        menu.pointSubmenu(at: 2)
        let picked = menu.selectedRow?.title
        menu.point(at: 2)
        let kept = menu.selectedRow?.title
        menu.point(at: 1)

        XCTAssertEqual(opened, 2)
        XCTAssertEqual(picked, "Reset Icon")
        XCTAssertEqual(kept, "Reset Icon")
        XCTAssertNil(menu.submenu)
        XCTAssertEqual(menu.selectedRow?.title, "New")
    }

    func testASearchFindsAChildByItsWordsUnderItsParentsTitle() throws {
        var menu = try XCTUnwrap(ActionMenu(spot: command(), item: nil, offered: icon()))

        menu.search("draw")

        XCTAssertEqual(menu.shown.map(\.title), ["Change Icon › Draw…"])
        XCTAssertEqual(menu.selectedRow?.action?.id, "change.draw")
        XCTAssertEqual(menu.selectedRow?.owner, "openspot/icon")
    }
}
