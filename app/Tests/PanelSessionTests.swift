import XCTest
@testable import OpenspotCore

@MainActor
final class PanelSessionTests: PanelCase {
    private var clock = FakeClock()
    private let close = ActionKey(name: "w", isCommand: true)

    override func setUp() async throws {
        try await super.setUp()
        let files = model.files
        model.quit()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(opening: SheetOpening(motionLength: motionLength), clock: clock.value, stopPause: stopPause, timeline: files.timeline))
        host.model = model
        try script("parts", toml: "title = 'Parts'", "printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n'")
        try script("other", toml: "title = 'Other'", "printf 'item=o\\ntitle=Other\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
    }

    private func openParts() async throws {
        model.pushFirst("parts", moving: true)
        try await wait("the open parts") { self.model.openSheetID == "parts" && self.model.openParts != nil }
    }

    private func openOther() async throws {
        model.pushFirst("other", moving: true)
        try await wait("the open other") { self.model.openSheetID == "other" }
    }

    private func clickOutside() {
        model.panelWillHide()
        model.panelDidHide()
    }

    private func reopen() {
        model.isShown = true
        model.panelWillShow()
    }

    func testAClickOutsideAndAReopenSoonBringBackTheSheetOfParts() async throws {
        try await openParts()

        clickOutside()
        XCTAssertNil(model.openSheetID)
        clock.advance(by: 30)
        reopen()

        try await wait("the parts again") { self.model.openSheetID == "parts" && self.model.openParts != nil }
        XCTAssertEqual(model.flow.current?.spot, "parts")
    }

    func testAReopenSelectsTheTextThatCameBack() async throws {
        model.search("ban")
        let selections = model.textSelections

        clickOutside()
        reopen()

        XCTAssertEqual(model.searchText, "ban")
        XCTAssertEqual(model.textSelections, selections + 1)
    }

    func testAReopenAfterTheRestoreTimeOpensAnEmptySearch() async throws {
        model.search("ban")
        try await openOther()

        clickOutside()
        clock.advance(by: PanelSession.restoreTime + 1)
        reopen()

        XCTAssertEqual(model.searchText, "")
        XCTAssertNil(model.openSheetID)
        XCTAssertNil(model.flow.current)
    }

    func testAReopenJustInsideTheRestoreTimeStillRestores() async throws {
        model.search("ban")

        clickOutside()
        clock.advance(by: PanelSession.restoreTime - 1)
        reopen()

        XCTAssertEqual(model.searchText, "ban")
    }

    func testEscToTheEndStartsTheNextOpenClean() async throws {
        try await openParts()

        XCTAssertTrue(model.handleKey(escape))
        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(host.dismissals, 1)
        reopen()

        XCTAssertNil(model.openSheetID)
        XCTAssertNil(model.flow.current)
    }

    func testCommandWClosesThePanelFromASheetAndTheNextOpenIsEmpty() async throws {
        model.search("ban")
        try await openOther()

        XCTAssertTrue(model.handleKey(close))
        XCTAssertEqual(host.dismissals, 1)
        reopen()

        XCTAssertEqual(model.searchText, "")
        XCTAssertNil(model.openSheetID)
    }

    func testCommandWClosesThePanelFromTheGridWithText() async throws {
        model.search("ban")

        XCTAssertTrue(model.handleKey(close))
        reopen()

        XCTAssertEqual(host.dismissals, 1)
        XCTAssertEqual(model.searchText, "")
    }

    func testAnActionThatClosesThePanelParksTheSession() async throws {
        model.search("ban")

        model.hidePanel(after: .close)
        reopen()

        XCTAssertEqual(host.dismissals, 1)

        XCTAssertEqual(model.searchText, "ban")
    }

    func testOpeningAnotherSpotWhileParkedShowsThatSpotAlone() async throws {
        try await openParts()
        clickOutside()

        XCTAssertTrue(model.open("other"))
        XCTAssertNil(model.flow.current)
        reopen()

        try await wait("the other sheet") { self.model.openSheetID == "other" }
        XCTAssertEqual(model.flow.pages.map(\.spot), ["other"])
    }

    func testEscInARestoredSheetGoesToTheGridAndThenEndsTheSession() async throws {
        try await openParts()
        clickOutside()
        reopen()
        try await wait("the parts again") { self.model.openSheetID == "parts" }

        XCTAssertTrue(model.handleKey(escape))
        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertTrue(model.handleKey(escape))

        XCTAssertEqual(host.dismissals, 1)
        reopen()
        XCTAssertNil(model.openSheetID)
    }

    func testTheRestoreTimeOfTheConfigDecidesHowLongAParkedPlaceWaits() async throws {
        _ = try model.files.config.change { $0.set(restoreWithin: "5 minutes") }
        await model.reload()
        model.search("ban")

        clickOutside()
        clock.advance(by: 200)
        reopen()

        XCTAssertEqual(model.searchText, "ban")
    }

    func testTheRestoreTimeIsAChoiceOfGeneralAndAnUnknownOneIsAFault() throws {
        let row = try XCTUnwrap(AppSetting.rows([.restore: "90 seconds"]).first)

        XCTAssertEqual(row.section, .general)
        XCTAssertEqual(row.choices, ["30 seconds", "90 seconds", "5 minutes", "1 hour"])
        XCTAssertEqual(Config(text: "restore-within = \"1 hour\"\n").restoreTime, 3600)
        XCTAssertEqual(Config(text: "restore-within = \"forever\"\n").faults, ["config.toml: restore-within is \"30 seconds\", \"90 seconds\", \"5 minutes\", \"1 hour\"."])
    }

    func testADragOntoTheHiddenPanelDoesNotBringBackTheParkedSheet() async throws {
        try await openParts()
        model.search("ban")
        clickOutside()

        model.prepareForDrag()
        reopen()

        XCTAssertNil(model.openSheetID)
    }

    func testARevealOfACardWhileParkedShowsTheCardAndNotTheParkedSheet() async throws {
        try await openParts()
        clickOutside()

        XCTAssertTrue(model.showCard("other"))
        try await wait("the grid") { self.model.isShown }

        XCTAssertNil(model.openSheetID)
        XCTAssertEqual(model.selectedEntry?.id, "other")
    }

    func testACommandKeyWhileHiddenKeepsTheRestoreTime() async throws {
        try script("ping", toml: "title = 'Ping'\n[actions.ping]\ntitle = 'Ping'", "true")
        await model.reload()
        model.search("ban")
        clickOutside()

        model.press(GlobalKey(spot: "ping", command: "ping", shortcut: try XCTUnwrap(Shortcut(text: "ctrl+p"))))
        clock.advance(by: PanelSession.restoreTime + 1)
        reopen()

        XCTAssertEqual(model.searchText, "")
    }
}
