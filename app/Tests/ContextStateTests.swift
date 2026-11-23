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

        try await wait("the drop") { self.log("keep-drops").count == 1 }
        XCTAssertEqual(log("keep-drops"), ["input.url=https://example.com/a"])
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
}
