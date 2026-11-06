import XCTest
@testable import OpenspotCore

final class SheetSandboxTests: XCTestCase {
    func testEachExampleHasNoFaults() {
        for example in SheetExamples.all {
            XCTAssertEqual(PluginOutput(text: example.text).sheetFaults, [], example.name)
        }
    }

    func testTextDrawsASheetAndReportsItsFaults() {
        var sandbox = SheetSandbox()
        sandbox.take(text: "grid=a\n\npart=a\ncell=b\ntitle=A\n")

        XCTAssertEqual(sandbox.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(sandbox.faults, ["the part a names the cell b, which the drawing does not have"])
    }

    func testTextThatDrawsNothingLeavesTheLastSheet() {
        var sandbox = SheetSandbox()
        sandbox.take(text: "part=a\ntitle=A\n")
        sandbox.take(text: "gri")

        XCTAssertEqual(sandbox.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(sandbox.text, "gri")
        XCTAssertFalse(sandbox.faults.isEmpty)
    }

    func testAChangeShowsAtOnceAndIsLogged() {
        var sandbox = SheetSandbox()
        sandbox.take(text: "part=a\non=false\n")

        sandbox.set("true", of: "a")
        sandbox.press("a")

        XCTAssertEqual(sandbox.panel?.parts.first?.control, .toggle(true))
        XCTAssertEqual(sandbox.log, ["a true", "a"])
    }

    func testAFrameOfAScriptShowsItsTextAndFaults() {
        var sandbox = SheetSandbox()

        sandbox.note(frame: "grid=a\n\npart=a\ncell=b\ntitle=A\n")

        XCTAssertEqual(sandbox.text, "grid=a\n\npart=a\ncell=b\ntitle=A\n")
        XCTAssertEqual(sandbox.faults, ["the part a names the cell b, which the drawing does not have"])
        XCTAssertNil(sandbox.panel)
    }
}
