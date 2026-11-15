import XCTest
@testable import OpenspotCore

final class PlaygroundTests: XCTestCase {
    func testThePlaygroundRunsAScriptOfEachStayingModeAsOneThatStaysWhileInUse() throws {
        let folder = try temporaryFolder()
        let modes = try ["stay", "always", "once", "inline"].map { mode in
            let file = folder.appendingPathComponent("\(mode).sh")
            try "#!/bin/sh\n# mode=\(mode)\n".write(to: file, atomically: true, encoding: .utf8)
            return Playground.command(file: file).mode
        }

        XCTAssertEqual(modes, [.stay, .stay, .once, .once])
    }

    func testANamedFileRunsInPlaceWithTheIDOfItsSpotsFolder() {
        let spots = URL(fileURLWithPath: "/p/spots")
        let scratch = URL(fileURLWithPath: "/t/playground")
        let place = { (file: String?, text: String) in
            Playground.place(of: file.map { URL(fileURLWithPath: $0) }, text: text, spots: spots, scratch: scratch)
        }

        XCTAssertEqual(place("/p/spots/home.spot/cups.sh", "").url.path, "/p/spots/home.spot/cups.sh")
        XCTAssertEqual(place("/p/spots/home.spot/cups.sh", "").id, "home/cups")
        XCTAssertEqual(place("/p/spots/cups.spot/cups.js", "").id, "cups")
        XCTAssertEqual(place("/elsewhere/tools/cups.sh", "").id, "cups")
        XCTAssertEqual(place(nil, "// title=A\n").url.path, "/t/playground/playground.js")
        XCTAssertEqual(place(nil, "#!/bin/sh\n").id, "playground")
    }

    func testEachExampleHasNoFaults() {
        for example in SheetExamples.all {
            XCTAssertEqual(FrameCheck(text: example.text).sheetFaults, [], example.name)
        }
    }

    func testTextDrawsASheetAndReportsItsFaults() {
        var playground = Playground()
        playground.take(text: "grid=b\n\ntext=a\ntitle=A\n")

        XCTAssertEqual(playground.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(playground.faults, ["the part a is not in the drawing"])
    }

    func testTextThatDrawsNothingLeavesTheLastSheet() {
        var playground = Playground()
        playground.take(text: "text=a\ntitle=A\n")
        playground.take(text: "gri")

        XCTAssertEqual(playground.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(playground.text, "gri")
        XCTAssertFalse(playground.faults.isEmpty)
    }

    func testAChangeShowsAtOnceAndIsLogged() {
        var playground = Playground()
        playground.take(text: "switch=a\nvalue=false\n")

        playground.set("true", of: "a")
        playground.press("a")

        XCTAssertEqual(playground.panel?.parts.first?.control, .toggle(true))
        XCTAssertEqual(playground.log, ["a true", "a"])
    }

    func testAFrameOfAScriptShowsItsTextAndFaults() {
        var playground = Playground()

        playground.note(frame: "grid=b\n\ntext=a\ntitle=A\n")

        XCTAssertEqual(playground.text, "grid=b\n\ntext=a\ntitle=A\n")
        XCTAssertEqual(playground.faults, ["the part a is not in the drawing"])
        XCTAssertNil(playground.panel)
    }
}
