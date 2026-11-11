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
        sandbox.take(text: "grid=b\n\ntext=a\ntitle=A\n")

        XCTAssertEqual(sandbox.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(sandbox.faults, ["the part a is not in the drawing"])
    }

    func testTextThatDrawsNothingLeavesTheLastSheet() {
        var sandbox = SheetSandbox()
        sandbox.take(text: "text=a\ntitle=A\n")
        sandbox.take(text: "gri")

        XCTAssertEqual(sandbox.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(sandbox.text, "gri")
        XCTAssertFalse(sandbox.faults.isEmpty)
    }

    func testAChangeShowsAtOnceAndIsLogged() {
        var sandbox = SheetSandbox()
        sandbox.take(text: "switch=a\nvalue=false\n")

        sandbox.set("true", of: "a")
        sandbox.press("a")

        XCTAssertEqual(sandbox.panel?.parts.first?.control, .toggle(true))
        XCTAssertEqual(sandbox.log, ["a true", "a"])
    }

    func testAFrameOfAScriptShowsItsTextAndFaults() {
        var sandbox = SheetSandbox()

        sandbox.note(frame: "grid=b\n\ntext=a\ntitle=A\n")

        XCTAssertEqual(sandbox.text, "grid=b\n\ntext=a\ntitle=A\n")
        XCTAssertEqual(sandbox.faults, ["the part a is not in the drawing"])
        XCTAssertNil(sandbox.panel)
    }
}
