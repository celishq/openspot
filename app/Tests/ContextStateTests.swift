import XCTest
@testable import OpenspotCore

@MainActor
final class ContextStateTests: ContextCase {
    private let tab = ActionKey(name: "tab")
    private let backTab = ActionKey(name: "tab", isShift: true)

    private func openWithTab(takers: [String] = ["keep"]) async throws {
        for name in takers { try taker(name, takes: "'url'") }
        try taker("reader", takes: "'text'")
        try source(adds: "url=https://example.com/a title=A")
        await open()
        try await wait("the value of the tab") { self.model.context.chips.first?.value != nil }
    }

    private var shown: [String] {
        model.visible.map(\.state.title)
    }

    func testTabSelectsTheFirstChipAndShowsItsPreviewAndTheSpotsThatTakeIt() async throws {
        try await openWithTab()

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(model.context.selected, "tab")
        XCTAssertEqual(shown, ["A", "keep"])
        XCTAssertEqual(model.selected, 1)
    }

    func testTabAndShiftTabTurnTheChipsAndWrap() async throws {
        try taker("reader", takes: "'text', 'url'")
        try source(adds: "url=https://example.com/a")
        try source("selection", adds: "text=hola app=com.apple.Safari")
        await open()
        try await wait("two values") { self.model.context.chips.allSatisfy { $0.value != nil } && self.model.context.chips.count == 2 }

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(model.context.selected, "selection")
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(model.context.selected, "tab")
        XCTAssertEqual(model.context.stack.map(\.source), ["tab", "selection"])
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(model.context.selected, "selection")
        XCTAssertTrue(model.handleKey(backTab))
        XCTAssertEqual(model.context.selected, "tab")
    }

    func testEscLeavesTheContextAndBringsBackTheGrid() async throws {
        try await openWithTab()
        let grid = shown

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(escape))

        XCTAssertFalse(model.context.isOn)
        XCTAssertEqual(shown, grid)
        XCTAssertEqual(host.dismissals, 0)
    }

    func testTypingFiltersTheRowsAndKeepsThePreview() async throws {
        try await openWithTab(takers: ["keep", "save"])
        XCTAssertTrue(model.handleKey(tab))

        model.query = "sav"
        model.landSearch()

        XCTAssertEqual(shown, ["A", "save"])
        XCTAssertEqual(model.selected, 1)
    }

    func testTypingInTheContextBuildsTheIndexOfTakersOnce() async throws {
        try await openWithTab(takers: ["keep", "save"])
        XCTAssertTrue(model.handleKey(tab))
        let builds = model.spotListBuilds

        for text in ["s", "sa", "sav"] {
            model.query = text
            model.landSearch()
        }

        XCTAssertEqual(model.spotListBuilds, builds)
        XCTAssertEqual(shown, ["A", "save"])
    }

    func testThePreviewIsNeverSelected() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        model.moveSelection(dx: 0, dy: -1)
        model.tap(model.visible[0].id)

        XCTAssertEqual(model.selected, 1)
        XCTAssertTrue(model.context.isOn)
    }

    func testReturnHandsTheValueToTheDropOfTheSelectedRow() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        model.runSelected()

        try await wait("the drop") { self.log("keep-drops").count == 2 }
        XCTAssertEqual(log("keep-drops"), ["input.url=https://example.com/a", "input.title=A"])
        XCTAssertFalse(model.context.isOn)
    }

    func testTabWithNoChipLeavesTheKeyAlone() async throws {
        try taker(takes: "'url'")
        await open()

        XCTAssertFalse(model.handleKey(tab))
        XCTAssertFalse(model.context.isOn)
    }

    func testTabAfterASlashCompletesTheWordOfTheSelectedCommand() async throws {
        try script("translate", toml: "title = 'Translate'\n\n[on]\ncommand = ['translate']", "printf 'text=x\\ntitle=Translate\\n'")
        try await openWithTab()
        model.query = "/tra"
        model.landSearch()

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(model.query, "/translate ")
        XCTAssertFalse(model.context.isOn)
    }

    func testAChipThatFillsWhileItIsSelectedShowsItsRows() async throws {
        try taker(takes: "'url'")
        try source(waits: true, adds: "url=https://example.com/a title=A")
        await open()
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(shown, ["Loading"])

        FileManager.default.createFile(atPath: path("release"), contents: Data())

        try await wait("the rows of the value") { self.shown == ["A", "keep"] }
        XCTAssertEqual(model.selected, 1)
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
        model.landSearch()
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
        model.landSearch()
        try await wait("the answer") { self.model.visible.contains { $0.role == .answer } }
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.role == .answer })
        model.runSelected()

        XCTAssertTrue(model.context.isOn)
        XCTAssertEqual(log("echo-log"), [])
    }

    func testPointingAtThePreviewLeavesTheSelectionOnItsRow() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))
        let preview = try XCTUnwrap(model.placements.first { $0.index == 0 })

        model.point(at: .grid(CGPoint(x: preview.rect.midX, y: preview.rect.midY)))

        XCTAssertEqual(model.selected, 1)
    }

    func testALateAnswerKeepsTheRowsOfTheValue() async throws {
        try script("echo", toml: "title = 'Echo'\n\n[on]\nsearch = '.'", "printf 'item=x\\ntitle=Echo\\n'")
        try await openWithTab(takers: ["keep", "save"])
        XCTAssertTrue(model.handleKey(tab))

        model.query = "sav"
        model.landSearch()
        try await wait("the answer of Echo") { self.model.sheets["echo"]?.answers.isEmpty == false }

        XCTAssertEqual(shown, ["A", "save"])
        XCTAssertEqual(model.selected, 1)
    }

    func testCommandReturnOnATakerRowOpensNoSettings() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertFalse(model.openSelectedSettings())
        XCTAssertTrue(model.context.isOn)
    }

    func testAReopenShowsTheGridAndNoRowsOfTheLastContext() async throws {
        try await openWithTab()
        let grid = shown
        XCTAssertTrue(model.handleKey(tab))

        model.panelWillHide()
        model.panelDidHide()
        model.panelWillShow()

        XCTAssertFalse(model.context.isOn)
        XCTAssertEqual(shown.filter { $0 != "A" }, grid)
        XCTAssertFalse(shown.contains("A"))
    }

    func testAnotherSourceThatAnswersKeepsTheSelectedRow() async throws {
        try taker("keep", takes: "'url'")
        try taker("save", takes: "'url'")
        try source(adds: "url=https://example.com/a title=A")
        try source("copy", app: nil, waits: true, adds: "text=hola")
        try taker("reader", takes: "'text'")
        await open()
        try await wait("the tab") { self.model.context.chips.first?.value != nil }
        XCTAssertTrue(model.handleKey(tab))
        model.moveSelection(dx: 0, dy: 1)
        XCTAssertEqual(model.selected, 2)

        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the copy") { self.model.context.chips.count == 2 }

        XCTAssertEqual(model.selected, 2)
        XCTAssertEqual(model.context.selected, "tab")
    }

    func testEditSpotsShowsTheCardsWhileAChipIsSelected() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        model.beginEditing()

        XCTAssertFalse(shown.contains("A"))
    }

    func testTheActionsMenuHasNoTargetOnAContextRow() async throws {
        try await openWithTab()
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertNil(model.target)
    }
}
