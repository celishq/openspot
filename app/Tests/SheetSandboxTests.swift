import XCTest
@testable import OpenspotCore

final class SheetSandboxTests: XCTestCase {
    func testTheSandboxRunsAScriptOfEachStayingModeAsOneThatStaysWhileInUse() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("sandbox-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let modes = try ["stay", "always", "once", "inline"].map { mode in
            let file = folder.appendingPathComponent("\(mode).sh")
            try "#!/bin/sh\n# mode=\(mode)\n".write(to: file, atomically: true, encoding: .utf8)
            return SheetSandbox.command(file: file).mode
        }

        XCTAssertEqual(modes, [.stay, .stay, .once, .once])
    }

    func testANamedFileRunsInPlaceWithTheIDOfItsPluginsFolder() {
        let plugins = URL(fileURLWithPath: "/p/plugins")
        let scratch = URL(fileURLWithPath: "/t/playground")
        let place = { (file: String?, text: String) in
            SheetSandbox.place(of: file.map { URL(fileURLWithPath: $0) }, text: text, plugins: plugins, scratch: scratch)
        }

        XCTAssertEqual(place("/p/plugins/home/cups.sh", "").url.path, "/p/plugins/home/cups.sh")
        XCTAssertEqual(place("/p/plugins/home/cups.sh", "").id, "home/cups")
        XCTAssertEqual(place("/p/plugins/cups.js", "").id, "cups")
        XCTAssertEqual(place("/elsewhere/tools/cups.sh", "").id, "cups")
        XCTAssertEqual(place(nil, "// title=A\n").url.path, "/t/playground/playground.js")
        XCTAssertEqual(place(nil, "#!/bin/sh\n").id, "playground")
    }

    func testEachExampleHasNoFaults() {
        for example in SheetExamples.all {
            XCTAssertEqual(SpotOutput(text: example.text).sheetFaults, [], example.name)
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
