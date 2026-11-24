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
        XCTAssertEqual(model.fieldValue.preview?.text, "A")
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

        model.query = "k"
        XCTAssertTrue(model.isAttachmentHidden)
        model.query = ""
        XCTAssertFalse(model.isAttachmentHidden)

        XCTAssertTrue(model.handleKey(tab))
        model.query = "k"
        XCTAssertFalse(model.isAttachmentHidden)
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

    func testTypingFiltersTheRowsAndKeepsThePreview() async throws {
        try await openWithTab(takers: ["keep", "save"])
        XCTAssertTrue(model.handleKey(tab))

        model.query = "sav"

        XCTAssertEqual(model.fieldValue.preview?.text, "A")
        XCTAssertEqual(shown, ["save"])
        XCTAssertEqual(model.selected, 0)
    }

    func testTypingInTheAttachmentBuildsTheIndexOfTakersOnce() async throws {
        try await openWithTab(takers: ["keep", "save"])
        XCTAssertTrue(model.handleKey(tab))
        let builds = model.spotListBuilds

        for text in ["s", "sa", "sav"] {
            model.query = text
        }

        XCTAssertEqual(model.spotListBuilds, builds)
        XCTAssertEqual(shown, ["save"])
    }

    func testTheRowsStartBelowThePreview() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        model.moveSelection(dx: 0, dy: -1)

        XCTAssertEqual(model.fieldValue.lines, 1)
        XCTAssertEqual(model.placements.map(\.rect.minY), [model.fieldRoom])
        XCTAssertLessThan(model.fieldRoom, SpotTokens.cell + SpotTokens.rowGap)
        XCTAssertEqual(model.selected, 0)
    }

    func testReturnHandsTheValueToTheDropOfTheSelectedRow() async throws {
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
        XCTAssertEqual(model.fieldValue.preview?.caption, "Reading Safari…")

        FileManager.default.createFile(atPath: path("release"), contents: Data())

        try await wait("the rows of the value") { self.shown == ["keep"] }
        XCTAssertEqual(model.fieldValue.preview?.text, "A")
        XCTAssertEqual(model.selected, 0)
    }

    func testASlashRunsItsCommandWhileAChipIsSelected() async throws {
        try script("translate", toml: "title = 'Translate'\n\n[on]\ncommand = ['translate']\ndrop = ['url']", """
        case "$1" in
          command) echo command >> '\(path("translate-log"))' ;;
          drop) echo drop >> '\(path("translate-log"))' ;;
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
        try script("echo", toml: "title = 'Echo'\n\n[on]\nsearch = '.'\ndrop = ['url']", """
        case "$1" in
          drop) echo drop >> '\(path("echo-log"))' ;;
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

    func testCommandReturnOnATakerRowOpensNoSettings() async throws {
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
        XCTAssertNil(model.fieldValue.preview)
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

        XCTAssertNil(model.fieldValue.preview)
    }

    func testTheActionsMenuHasNoTargetOnAnAttachmentRow() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertNil(model.target)
    }
}
