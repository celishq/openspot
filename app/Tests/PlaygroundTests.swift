import XCTest
@testable import OpenspotCore

final class PlaygroundTests: XCTestCase {
    func testThePlaygroundRunsAScriptOfEachStayingModeAsOneThatStaysWhileInUse() throws {
        let folder = try temporaryFolder()
        let modes = try ["stay", "once", "inline"].map { mode in
            let file = folder.appendingPathComponent("\(mode).spot/\(mode).sh")
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try (mode == "stay" ? "stay = true\n" : "").write(to: file.deletingLastPathComponent().appendingPathComponent("spot.toml"), atomically: true, encoding: .utf8)
            try "#!/bin/sh\n".write(to: file, atomically: true, encoding: .utf8)
            return Playground.command(file: file).mode
        }

        XCTAssertEqual(modes, [.stay, .once, .once])
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
        XCTAssertEqual(place(nil, "export default { async show() { return '' } }\n").url.path, "/t/playground/playground.js")
        XCTAssertEqual(place(nil, "#!/bin/sh\n").id, "playground")
    }

    func testEachExampleHasNoFaults() {
        for example in SheetExamples.all {
            XCTAssertEqual(FrameCheck(text: example.text).sheetFaults, [], example.name)
        }
    }

    func testTextDrawsASheetAndReportsItsFaults() {
        var playground = Playground()
        playground.take(text: "frame=\nclass=gap-part glow\n\ntext=a\ntitle=A\n")

        XCTAssertEqual(playground.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(playground.faults, ["the root has an unknown class: glow"])
    }

    func testTextThatDrawsNothingLeavesTheLastSheet() {
        var playground = Playground()
        playground.take(text: "frame=\nclass=gap-part\n\ntext=a\ntitle=A\n")
        playground.take(text: "gri")

        XCTAssertEqual(playground.panel?.parts.map(\.id), ["a"])
        XCTAssertEqual(playground.text, "gri")
        XCTAssertFalse(playground.faults.isEmpty)
    }

    func testAChangeShowsAtOnceAndIsLogged() {
        var playground = Playground()
        playground.take(text: "frame=\nclass=gap-part\n\nswitch=a\nvalue=false\n")

        playground.set("true", of: "a")
        playground.press("a")

        XCTAssertEqual(playground.panel?.parts.first?.control, .toggle(true))
        XCTAssertEqual(playground.log, ["a true", "a"])
    }

    func testAFrameOfAScriptShowsItsTextAndFaults() {
        var playground = Playground()

        playground.note(frame: "frame=\nclass=gap-part glow\n\ntext=a\ntitle=A\n")

        XCTAssertEqual(playground.text, "frame=\nclass=gap-part glow\n\ntext=a\ntitle=A\n")
        XCTAssertEqual(playground.faults, ["the root has an unknown class: glow"])
        XCTAssertNil(playground.panel)
    }
}
