import XCTest
@testable import OpenspotCore

final class SheetFocusTests: XCTestCase {
    private func panel(_ text: String) throws -> SheetParts {
        try XCTUnwrap(SheetParts(output: SpotOutput(text: text)))
    }

    private let confetti = """
    grid=look look look look
    grid=key key key key
    grid=make make play play

    choice=look
    title=Look
    value=gold

    option=colorful
    title=Colorful

    option=gold
    title=Gold

    field=key
    type=hotkey
    title=Shortcut
    value=option+c

    button=make
    title=Make with AI
    align=center

    button=play
    look=strong
    title=Play
    align=center
    close=true

    button=paste
    title=Paste a look
    shortcut=cmd+shift+v
    """

    func test_A29_theArrowsReachEachDrawnPartInTheOrderItIsDrawnAndNoAction() throws {
        var sheet = try panel(confetti)

        XCTAssertEqual(sheet.focusOrder.map(\.id), ["look", "key", "make", "play"])
        XCTAssertEqual(sheet.selectedPart?.id, "look")
        sheet.moveLine(by: 1)
        XCTAssertEqual(sheet.selectedPart?.id, "key")
        sheet.moveLine(by: 1)
        XCTAssertEqual(sheet.selectedPart?.id, "make")
        sheet.move(by: 1)
        XCTAssertEqual(sheet.selectedPart?.id, "play")
        sheet.move(by: 1)
        sheet.moveLine(by: 1)
        XCTAssertEqual(sheet.selectedPart?.id, "play")
        sheet.moveLine(by: -2)
        XCTAssertEqual(sheet.selectedPart?.id, "look")
        sheet.moveLine(by: -1)
        XCTAssertEqual(sheet.selectedPart?.id, "look")
    }

    func testAMoveToAnotherLineTakesThePartClosestAcross() throws {
        var sheet = try panel("grid=a b\ngrid=c d\n\nbutton=a\ntitle=A\n\nbutton=b\ntitle=B\n\nbutton=c\ntitle=C\n\nbutton=d\ntitle=D\n")

        sheet.move(by: 1)
        sheet.moveLine(by: 1)
        XCTAssertEqual(sheet.selectedPart?.id, "d")
        sheet.move(by: -1)
        sheet.moveLine(by: -1)
        XCTAssertEqual(sheet.selectedPart?.id, "a")
    }

    func testAFieldTakesTheFocusFirstAndTheArrowsLeaveIt() throws {
        var sheet = try panel("grid=reload\ngrid=note\ngrid=level\n\nbutton=reload\ntitle=Reload\n\nfield=note\nvalue=Hello\n\nfield=level\ntype=slider\nvalue=50\n")

        XCTAssertTrue(sheet.takesArrows)
        XCTAssertEqual(sheet.selectedPart?.id, "note")
        sheet.moveLine(by: -1)
        XCTAssertEqual(sheet.selectedPart?.id, "reload")
        sheet.moveLine(by: 2)
        XCTAssertEqual(sheet.selectedPart?.id, "level")
    }

    func testAPartWithNothingToUseTakesNoFocus() throws {
        let sheet = try panel("text=mac\ntitle=This Mac\n\nfield=log\nvalue=Done\nreadonly=true\n\nswitch=wifi\nvalue=true\n")

        XCTAssertEqual(sheet.focusOrder.map(\.id), ["wifi"])
    }

    func testAClickIntoAFieldGivesItTheFocus() throws {
        var sheet = try panel("grid=reload note\n\nbutton=reload\ntitle=Reload\n\nfield=note\nvalue=Hello\n")

        sheet.focus("reload")
        XCTAssertEqual(sheet.selectedPart?.id, "reload")
        sheet.focus("nothing")
        XCTAssertEqual(sheet.selectedPart?.id, "reload")
    }

    func testTheRowsKeepTheArrowsUntilTheFocusLeavesThemForThePartsBelow() throws {
        var sheet = try panel("grid=top\ngrid=list\ngrid=add\n\nbutton=top\ntitle=Top\n\nrepeat=list\n\nbutton=add\ntitle=Add\n\nrow=a\ntitle=A\n")

        XCTAssertFalse(sheet.takesArrows)
        XCTAssertNil(sheet.selectedPart)
        XCTAssertEqual(sheet.focusOrder.map(\.id), ["add"])
        XCTAssertTrue(sheet.leaveRows())
        XCTAssertEqual(sheet.selectedPart?.id, "add")
        sheet.moveLine(by: -1)
        XCTAssertNil(sheet.selectedPart)
    }

    func testRowsWithNoPartBelowKeepTheFocus() throws {
        var sheet = try panel("grid=top\ngrid=list\n\nbutton=top\ntitle=Top\n\nrepeat=list\n\nrow=a\ntitle=A\n")

        XCTAssertFalse(sheet.leaveRows())
        XCTAssertNil(sheet.selectedPart)
    }
}
