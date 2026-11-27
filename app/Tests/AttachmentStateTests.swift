import XCTest
@testable import OpenspotCore

@MainActor
final class AttachmentStateTests: AttachmentCase {
    private let tab = ActionKey(name: "tab")
    private let backTab = ActionKey(name: "tab", isShift: true)

    private func openWithTab(takers: [String] = ["keep"]) async throws {
        for name in takers { try taker(name, takes: "'url'") }
        try taker("reader", takes: "'text'")
        try source(adds: "url=https://example.com/a title=A")
        await open()
        try await wait("the value of the tab") { self.model.attachments.chips.first?.value != nil }
    }

    private var shown: [String] {
        model.visible.map(\.state.title)
    }

    func testTabSelectsTheFirstChipAndShowsItsPreviewAndTheSpotsThatTakeIt() async throws {
        try await openWithTab()

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(model.attachments.selected, "tab")
        XCTAssertEqual(model.details?.label, "A")
        XCTAssertEqual(shown, ["keep"])
        XCTAssertEqual(model.selected, 0)
    }

    func testTheFooterOffersTabOnceAnAttachmentIsReady() async throws {
        try await openWithTab()

        XCTAssertTrue(model.hint.hasPrefix("⇥ Attach"))
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.hint.contains("⇥ Next"))
        XCTAssertFalse(model.hint.contains("⇥ Attach"))
    }

    func testTypingHidesTheAttachmentsUntilOneIsChosen() async throws {
        try await openWithTab()
        XCTAssertFalse(model.isAttachmentHidden)

        model.search("k")
        XCTAssertTrue(model.isAttachmentHidden)
        model.search("")
        XCTAssertFalse(model.isAttachmentHidden)

        XCTAssertTrue(model.handleKey(tab))
        model.search("k")
        XCTAssertFalse(model.isAttachmentHidden)
    }

    func testAReopenWithKeptTextKeepsTheChipsHiddenWhileTheirReadsArrive() async throws {
        try await openWithTab()
        model.search("k")
        XCTAssertTrue(model.isAttachmentHidden)
        model.panelWillHide()
        model.panelDidHide()
        let writes = host.hiddenWrites.count

        await open()
        XCTAssertTrue(model.isAttachmentHidden)
        try await wait("the value of the tab again") { self.model.attachments.chips.first?.value != nil }

        XCTAssertTrue(model.isAttachmentHidden)
        XCTAssertEqual(host.hiddenWrites.count, writes)
    }

    func testAWriteOfTheQueryMakesNoChangeOfItsOwn() async throws {
        try await openWithTab()
        let changes = host.motions.count

        model.query = "k"

        XCTAssertEqual(host.motions.count, changes)
    }

    func testTheStackFadesOutOnTypingAndBackOnTabEachInAChangeOfItsOwn() async throws {
        try await openWithTab()
        let writes = host.hiddenWrites.count

        model.search("k")
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertFalse(model.isAttachmentHidden)
        XCTAssertEqual(host.hiddenWrites.dropFirst(writes).map(\.motion), [.fade, .fade])
        XCTAssertEqual(host.hiddenWrites.dropFirst(writes).map(\.depth), [0, 0])
    }

    func testTheFadeOfTheStackIsTheFirstChangeOfTheTypedLetter() async throws {
        try await openWithTab()
        let writes = host.hiddenWrites.count

        model.search("k")

        XCTAssertEqual(host.hiddenWrites.dropFirst(writes).map(\.query), [""])
        XCTAssertEqual(model.query, "k")
    }

    func testAWriteOfTheQueryThatLeavesTheChipsMakesNoChangeOfItsOwn() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))
        let changes = host.motions.count

        model.query = "/"

        XCTAssertNil(model.details)
        XCTAssertEqual(host.motions.count, changes)
    }

    func testAWriteOfTheEntriesThatDropsTheSourceMakesNoChangeOfItsOwn() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))
        let changes = host.motions.count

        model.entries = model.entries.filter { $0.id != "tab" }

        XCTAssertNil(model.details)
        XCTAssertEqual(host.motions.count, changes)
    }

    func testThePreviewGivesWayOnTypingASlashInAChangeOfItsOwn() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))
        let writes = host.detailsWrites.count

        model.search("/")

        XCTAssertNil(model.details)
        XCTAssertEqual(host.detailsWrites.dropFirst(writes).map(\.motion), [.sheet(isOpen: false)])
        XCTAssertEqual(host.detailsWrites.dropFirst(writes).map(\.depth), [0])
    }

    func testThePreviewGivesWayToEditSpotsInOneChange() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))
        let writes = host.detailsWrites.count

        model.beginEditing()

        XCTAssertNil(model.details)
        XCTAssertEqual(host.detailsWrites.dropFirst(writes).map(\.motion), [.sheet(isOpen: false)])
        XCTAssertEqual(host.detailsWrites.dropFirst(writes).map(\.depth), [0])
    }

    func testTabWritesThePlacedStackAndThePreviewInOneChange() async throws {
        try await openWithTab()
        host.heldEnds = []
        let changes = host.motions.count
        let writes = host.detailsWrites.count

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(Array(host.motions.dropFirst(changes)), [.sheet(isOpen: true)])
        XCTAssertEqual(host.detailsWrites.dropFirst(writes).map(\.motion), [.sheet(isOpen: true)])
        XCTAssertTrue(model.attachments.isMoving)
        XCTAssertEqual(model.details?.label, "A")
    }

    func testTabGrowsTheFieldForThePreviewOnTheSheetsOpenWithTheRowsLaidInTheSameChange() async throws {
        try await openWithTab()
        let previews = host.detailsWrites.count
        let placements = host.placementWrites.count

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(host.detailsWrites.dropFirst(previews).map(\.motion), [.sheet(isOpen: true)])
        XCTAssertEqual(host.placementWrites.dropFirst(placements).map(\.motion), [.sheet(isOpen: true)])
        XCTAssertEqual(model.placements.first?.drop, model.detailsRoom)
    }

    func testEscShrinksTheFieldOnTheSheetsCloseWithTheCardsLaidInTheSameChange() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))
        let previews = host.detailsWrites.count
        let placements = host.placementWrites.count

        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))

        XCTAssertNil(model.details)
        XCTAssertEqual(host.detailsWrites.dropFirst(previews).map(\.motion), [.sheet(isOpen: false)])
        XCTAssertEqual(host.placementWrites.dropFirst(placements).map(\.motion), [.sheet(isOpen: false)])
    }

    func testATabToAChipOfAnotherHeightGrowsOrShrinksTheFieldOnTheSheetsMotion() async throws {
        try taker("keep", takes: "'url'")
        try taker("reader", takes: "'text'")
        try source(adds: "url=https://example.com/a title=A")
        try source("long", adds: "'text=\(String(repeating: "word ", count: 60))' title=Long")
        await open()
        try await wait("both values") { self.model.attachments.chips.filter { $0.value != nil }.count == 2 }
        XCTAssertTrue(model.handleKey(tab))
        let room = model.detailsRoom
        let previews = host.detailsWrites.count

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertNotEqual(model.detailsRoom, room)
        XCTAssertEqual(host.detailsWrites.dropFirst(previews).map(\.motion), [.sheet(isOpen: model.detailsRoom > room)])
    }

    func testEscKeepsTheLookOfThePreviewForItsClose() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))

        XCTAssertNil(model.details)
        XCTAssertEqual(model.heldDetails?.label, "A")
    }

    func testATapOnTheAttachmentsWorksTheHintOutOnceByTheEndOfThePress() async throws {
        try await openWithTab()
        model.followHint()
        await Task { @MainActor in }.value
        let takes = model.hintTakes
        let writes = host.hintWrites.count

        model.pressAttachment()

        XCTAssertEqual(model.attachments.selected, "tab")
        XCTAssertEqual(model.hintTakes - takes, 1)
        XCTAssertEqual(model.gridHint, HintWords(model.hint))
        XCTAssertEqual(host.hintWrites.count, writes)
    }

    func testTabAndShiftTabTurnTheChipsAndWrap() async throws {
        try taker("reader", takes: "'text', 'url'")
        try source(adds: "url=https://example.com/a")
        try source("selection", adds: "text=hola app=com.apple.Safari")
        await open()
        try await wait("two values") { self.model.attachments.chips.allSatisfy { $0.value != nil } && self.model.attachments.chips.count == 2 }
        let order = model.attachments.layout.places.map(\.chip.source)

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(model.attachments.selected, order[0])
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(model.attachments.selected, order[1])
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(model.attachments.selected, order[0])
        XCTAssertTrue(model.handleKey(backTab))
        XCTAssertEqual(model.attachments.selected, order[1])
    }

    func testEscLeavesTheAttachmentAndBringsBackTheGrid() async throws {
        try await openWithTab()
        let grid = shown

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(escape))

        XCTAssertFalse(model.attachments.isOn)
        XCTAssertEqual(shown, grid)
        XCTAssertEqual(host.dismissals, 0)
    }

    func testTypingFiltersTheRowsAndKeepsTheDetails() async throws {
        try await openWithTab(takers: ["keep", "save"])
        XCTAssertTrue(model.handleKey(tab))

        model.query = "sav"

        XCTAssertEqual(model.details?.label, "A")
        XCTAssertEqual(shown, ["save"])
        XCTAssertEqual(model.selected, 0)
    }

    func testTypingInTheAttachmentBuildsTheIndexOfChipRowsOnce() async throws {
        try await openWithTab(takers: ["keep", "save"])
        XCTAssertTrue(model.handleKey(tab))
        let builds = model.spotListBuilds

        for text in ["s", "sa", "sav"] {
            model.query = text
        }

        XCTAssertEqual(model.spotListBuilds, builds)
        XCTAssertEqual(shown, ["save"])
    }

    func testTypingInTheAttachmentFitsTheActionsAndKeepsTheDetails() async throws {
        try await openWithTab(takers: ["keep", "save"])
        XCTAssertTrue(model.handleKey(tab))
        let fits = model.commands.fits

        for text in ["s", "sa", "sav"] {
            model.search(text)
        }

        XCTAssertEqual(model.commands.fits, fits)
        XCTAssertEqual(shown, ["save"])
        XCTAssertEqual(model.details?.label, "A")
    }

    func testTheRowsStartBelowTheDetails() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        model.moveSelection(dx: 0, dy: -1)

        XCTAssertEqual(model.details?.lines, 1)
        XCTAssertEqual(model.placements.map(\.rect.minY), [model.detailsRoom])
        XCTAssertLessThan(model.detailsRoom, SpotTokens.cell + SpotTokens.rowGap)
        XCTAssertEqual(model.selected, 0)
    }

    func testASheetThatOpensFromTheFieldWhileThePreviewHoldsRoomKeepsTheRoomThroughItsOpen() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))
        let room = model.detailsRoom
        XCTAssertGreaterThan(room, 0)
        let writes = host.detailsWrites.count

        model.pushFirst("reader", moving: true)
        try await wait("the open") { self.model.transition.phase == .open }

        XCTAssertNil(SpotSheetCard.of("reader", in: model))
        XCTAssertEqual(model.detailsRoom, room)
        XCTAssertEqual(host.detailsWrites.count, writes)
    }

    func testReturnHandsTheValueToTheActionOfTheSelectedRow() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        model.runSelected()

        try await wait("the drop") { self.log("keep-drops").count == 2 }
        XCTAssertEqual(log("keep-drops"), ["input.url=https://example.com/a", "input.title=A"])
        XCTAssertFalse(model.attachments.isOn)
    }

    func testTabWithNoChipLeavesTheKeyAlone() async throws {
        try taker(takes: "'url'")
        await open()

        XCTAssertFalse(model.handleKey(tab))
        XCTAssertFalse(model.attachments.isOn)
    }

    func testTabAfterASlashCompletesTheWordOfTheSelectedCommand() async throws {
        try script("translate", toml: "title = 'Translate'\n\n[on]\ncommand = ['translate']", "printf 'text=x\\ntitle=Translate\\n'")
        try await openWithTab()
        model.query = "/tra"

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(model.query, "/translate ")
        XCTAssertFalse(model.attachments.isOn)
    }

    func testAChipThatFillsWhileItIsSelectedShowsItsRows() async throws {
        try taker(takes: "'url'")
        try pickSource(waits: true, runs: "\(cli) attachment add url=https://example.com/a title=A")
        await open()
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(shown, [])
        XCTAssertEqual(model.details?.label, "Reading Safari…")

        FileManager.default.createFile(atPath: path("release"), contents: Data())

        try await wait("the rows of the value") { self.shown == ["keep"] }
        XCTAssertEqual(model.details?.label, "A")
        XCTAssertEqual(model.selected, 0)
    }

    func testASlashRunsItsCommandWhileAChipIsSelected() async throws {
        try script("translate", toml: "title = 'Translate'\n[actions.take]\ntitle = 'Take'\ninputs.url = { type = 'url', required = true }\n\n[on]\ncommand = ['translate']", """
        case "$1" in
          command) echo command >> '\(path("translate-log"))' ;;
          take) echo take >> '\(path("translate-log"))' ;;
          *) printf 'text=x\\ntitle=Translate\\n' ;;
        esac
        """)
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        model.query = "/translate hola"
        model.runSelected()

        try await wait("the command") { self.log("translate-log") == ["command"] }
    }

    func testASlashThatNamesNoCommandSearchesAndHandsNothingToAnAnswer() async throws {
        try script("echo", toml: "title = 'Echo'\n[actions.take]\ntitle = 'Take'\ninputs.url = { type = 'url', required = true }\n\n[on]\nsearch = '.'", """
        case "$1" in
          take) echo take >> '\(path("echo-log"))' ;;
          *) printf 'item=x\\ntitle=Echo\\n' ;;
        esac
        """)
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        model.query = "/zz"
        try await wait("the answer") { self.model.visible.contains { $0.role == .answer } }
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.role == .answer })
        model.runSelected()

        XCTAssertTrue(model.attachments.isOn)
        XCTAssertEqual(log("echo-log"), [])
    }

    func testPointingAtThePreviewLeavesTheSelectionOnItsRow() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))
        let row = try XCTUnwrap(model.placements.first)

        model.point(at: .grid(CGPoint(x: row.rect.midX, y: row.rect.midY - row.rect.height - SpotTokens.rowGap)))

        XCTAssertEqual(model.selected, 0)
        XCTAssertNil(model.pointedCard)
    }

    func testALateAnswerKeepsTheRowsOfTheValue() async throws {
        try script("echo", toml: "title = 'Echo'\n\n[on]\nsearch = '.'", "printf 'item=x\\ntitle=Echo\\n'")
        try await openWithTab(takers: ["keep", "save"])
        XCTAssertTrue(model.handleKey(tab))

        model.query = "sav"
        try await wait("the answer of Echo") { self.model.sheets["echo"]?.answers.isEmpty == false }

        XCTAssertEqual(shown, ["save"])
        XCTAssertEqual(model.selected, 0)
    }

    func testCommandReturnOnAChipRowOpensNoSettings() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertFalse(model.openSelectedSettings())
        XCTAssertTrue(model.attachments.isOn)
    }

    func testAReopenShowsTheGridAndNoRowsOfTheLastAttachment() async throws {
        try await openWithTab()
        let grid = shown
        XCTAssertTrue(model.handleKey(tab))

        model.panelWillHide()
        model.panelDidHide()
        model.panelWillShow()

        XCTAssertFalse(model.attachments.isOn)
        XCTAssertEqual(shown, grid)
        XCTAssertNil(model.details)
    }

    func testTheFieldSearchesActionsWhileAChipIsChosenAndSpotsAfterEscOrAReopen() async throws {
        try await openWithTab()
        XCTAssertEqual(model.promptWord, "spots")

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(model.promptWord, "actions")
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(model.promptWord, "spots")

        XCTAssertTrue(model.handleKey(tab))
        model.panelWillHide()
        model.panelDidHide()
        model.panelWillShow()
        XCTAssertEqual(model.promptWord, "spots")
    }

    func testTurningToAnotherChipTellsNoReaderOfTheFieldsWord() async throws {
        try taker("reader", takes: "'text', 'url'")
        try source(adds: "url=https://example.com/a")
        try source("selection", adds: "text=hola app=com.apple.Safari")
        await open()
        try await wait("two values") { self.model.attachments.chips.allSatisfy { $0.value != nil } && self.model.attachments.chips.count == 2 }
        XCTAssertTrue(model.handleKey(tab))
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = model.promptWord } onChange: { changed = true }

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertFalse(changed)
        XCTAssertEqual(model.promptWord, "actions")
    }

    func testAnotherSourceThatAnswersKeepsTheSelectedRow() async throws {
        try taker("keep", takes: "'url'")
        try taker("save", takes: "'url'")
        try source(adds: "url=https://example.com/a title=A")
        try source("copy", waits: true, adds: "text=hola")
        try taker("reader", takes: "'text'")
        await open()
        try await wait("the tab") { self.model.attachments.chips.first?.value != nil }
        XCTAssertTrue(model.handleKey(tab))
        model.moveSelection(dx: 0, dy: 1)
        XCTAssertEqual(model.selected, 1)

        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the copy") { self.model.attachments.chips.count == 2 }

        XCTAssertEqual(model.selected, 1)
        XCTAssertEqual(model.attachments.selected, "tab")
    }

    func testEditSpotsShowsTheCardsWhileAChipIsSelected() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        model.beginEditing()

        XCTAssertNil(model.details)
    }

    func testTheActionsMenuHasNoTargetOnAnAttachmentRow() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertNil(model.target)
    }
}
