import XCTest
@testable import OpenspotCore

final class SheetFocusTests: XCTestCase {
    private func panel(_ text: String) throws -> SheetParts {
        try XCTUnwrap(SheetParts(output: Frame(text: text)))
    }

    private let confetti = """
    frame=
    class=gap-part

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

    box=foot
    class=flex-row gap-part

    button=make
    parent=foot
    title=Make with AI
    align=center

    button=play
    parent=foot
    look=strong
    title=Play
    align=center
    close=true
    """

    func testTheArrowsReachEachPartInTheOrderItIsDrawn() throws {
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
        var sheet = try panel("frame=\nclass=gap-part\n\nbox=top\nclass=flex-row gap-part\n\nbutton=a\nparent=top\ntitle=A\n\nbutton=b\nparent=top\ntitle=B\n\nbox=bottom\nclass=flex-row gap-part\n\nbutton=c\nparent=bottom\ntitle=C\n\nbutton=d\nparent=bottom\ntitle=D\n")

        sheet.move(by: 1)
        sheet.moveLine(by: 1)
        XCTAssertEqual(sheet.selectedPart?.id, "d")
        sheet.move(by: -1)
        sheet.moveLine(by: -1)
        XCTAssertEqual(sheet.selectedPart?.id, "a")
    }

    func testAFieldTakesTheFocusFirstAndTheArrowsLeaveIt() throws {
        var sheet = try panel("frame=\nclass=gap-part\n\nbutton=reload\ntitle=Reload\n\nfield=note\nvalue=Hello\n\nfield=level\ntype=slider\nvalue=50\n")

        XCTAssertTrue(sheet.takesArrows)
        XCTAssertEqual(sheet.selectedPart?.id, "note")
        sheet.moveLine(by: -1)
        XCTAssertEqual(sheet.selectedPart?.id, "reload")
        sheet.moveLine(by: 2)
        XCTAssertEqual(sheet.selectedPart?.id, "level")
    }

    func testAPartWithNothingToUseTakesNoFocus() throws {
        let sheet = try panel("frame=\nclass=gap-part\n\ntext=mac\ntitle=This Mac\n\nfield=log\nvalue=Done\nreadonly=true\n\nswitch=wifi\nvalue=true\n")

        XCTAssertEqual(sheet.focusOrder.map(\.id), ["wifi"])
    }

    func testAClickIntoAFieldGivesItTheFocus() throws {
        var sheet = try panel("frame=\nclass=flex-row gap-part\n\nbutton=reload\ntitle=Reload\n\nfield=note\nvalue=Hello\n")

        sheet.focus("reload")
        XCTAssertEqual(sheet.selectedPart?.id, "reload")
        sheet.focus("nothing")
        XCTAssertEqual(sheet.selectedPart?.id, "reload")
    }

    func testTheRowsKeepTheArrowsUntilTheFocusLeavesThemForThePartsBelow() throws {
        var sheet = try panel("frame=\nclass=gap-part\n\nbutton=top\ntitle=Top\n\nitems=list\n\nbutton=add\ntitle=Add\n\ntext=a\nparent=list\ntitle=A\n")

        XCTAssertFalse(sheet.takesArrows)
        XCTAssertNil(sheet.selectedPart)
        XCTAssertEqual(sheet.focusOrder.map(\.id), ["add"])
        XCTAssertTrue(sheet.leaveRows())
        XCTAssertEqual(sheet.selectedPart?.id, "add")
        sheet.moveLine(by: -1)
        XCTAssertNil(sheet.selectedPart)
    }

    func testRowsWithNoPartBelowKeepTheFocus() throws {
        var sheet = try panel("frame=\nclass=gap-part\n\nbutton=top\ntitle=Top\n\nitems=list\n\ntext=a\nparent=list\ntitle=A\n")

        XCTAssertFalse(sheet.leaveRows())
        XCTAssertNil(sheet.selectedPart)
    }

    private let placed = "frame=\nclass=gap-part\n\nbox=one\nclass=float:flex-row\n\nbutton=a\nparent=one\ntitle=A\n\nbutton=b\nparent=one\ntitle=B\n\nbox=two\nclass=light:flex-row\n\nbutton=c\nparent=two\ntitle=C\n\nbutton=d\nparent=two\ntitle=D\n"

    func testTheFocusLinesFollowThePlaceAndTheAppearanceTheSheetShowsIn() throws {
        var sheet = try XCTUnwrap(SheetParts(output: Frame(text: placed), variants: [.sheet, .dark]))
        XCTAssertEqual(sheet.focusOrder.map(\.id), ["a", "b", "c", "d"])
        sheet.moveLine(by: 1)
        XCTAssertEqual(sheet.selectedPart?.id, "b")

        var float = try XCTUnwrap(SheetParts(output: Frame(text: placed), variants: [.float, .light]))
        float.moveLine(by: 1)
        XCTAssertEqual(float.selectedPart?.id, "c")
        float.move(by: 1)
        XCTAssertEqual(float.selectedPart?.id, "d")
    }
}
