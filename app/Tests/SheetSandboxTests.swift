import XCTest
@testable import OpenspotCore

final class SheetSandboxTests: XCTestCase {
    func testEachExampleHasNoFaults() {
        for example in SheetExamples.all {
            XCTAssertEqual(PluginOutput(text: example.text).sheetFaults, [], example.name)
        }
    }

    func testEachNamedLayoutHasAnExample() {
        let names = Set(SheetExamples.all.map(\.name))
        for name in SheetLayout.named.keys {
            XCTAssertTrue(names.contains(name), name)
        }
    }

    func testTextDrawsASheetAndReportsItsFaults() {
        var sandbox = SheetSandbox()
        sandbox.take(text: "grid=a b\n\npart=a\ncell=a\ntitle=A\n")

        XCTAssertEqual(sandbox.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(sandbox.faults, ["the letter b has no part"])
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

        sandbox.note(frame: "grid=a b\n\npart=a\ncell=a\ntitle=A\n")

        XCTAssertEqual(sandbox.text, "grid=a b\n\npart=a\ncell=a\ntitle=A\n")
        XCTAssertEqual(sandbox.faults, ["the letter b has no part"])
        XCTAssertNil(sandbox.panel)
    }
}
