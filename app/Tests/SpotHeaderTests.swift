import XCTest
@testable import OpenspotCore

final class SpotHeaderTests: XCTestCase {
    func testAScriptWithCommandsHasNoCardOnTheGridAndStaysInTheScan() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-grid-\(UUID().uuidString)")
        try Data("#!/bin/sh\n#\n# command=left\n# title=Left side\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        defer { try? FileManager.default.removeItem(at: url) }

        let command = try XCTUnwrap(try SpotFile(file: url, id: "script")?.spots.first)

        XCTAssertFalse(command.headerState.isOnGrid)
    }

    func testOffersNamesThePlacesThatASpotIsMadeFor() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-grid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let searchOnly = folder.appendingPathComponent("search.sh")
        let rowsOnly = folder.appendingPathComponent("rows.sh"), floating = folder.appendingPathComponent("float.sh")
        try "#!/bin/sh\n# read=panel\n# offers=search\n".writeScript(to: searchOnly)
        try "#!/bin/sh\n# read=panel\n# offers=rows\n".writeScript(to: rowsOnly)
        try "#!/bin/sh\n# read=sheet\n# offers=float\n".writeScript(to: floating)

        let search = try XCTUnwrap(try SpotFile(file: searchOnly, id: "search")?.spots.first)
        let rows = try XCTUnwrap(try SpotFile(file: rowsOnly, id: "rows")?.spots.first)
        let float = try XCTUnwrap(try SpotFile(file: floating, id: "float")?.spots.first)
        XCTAssertTrue(search.headerState.isOnGrid)
        XCTAssertTrue(search.isGlobal)
        XCTAssertTrue(search.isFound)
        XCTAssertTrue(rows.isGlobal)
        XCTAssertFalse(rows.isFound)
        XCTAssertFalse(rows.headerState.isOnGrid)
        XCTAssertTrue(float.offersFloat)
        XCTAssertFalse(float.isGlobal)
        XCTAssertFalse(search.offersFloat)
    }

    func testAnUnknownPlaceRefusesThePlugin() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-place-\(UUID().uuidString)")
        try "#!/bin/sh\n# read=panel\n# offers=dock\n".writeScript(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try SpotFile(file: url, id: "script")) { error in
            XCTAssertTrue((error as? SpotError)?.reason.contains("search, rows or float") == true, "\(error)")
        }
    }

    func testGlobalFloatAndTrayRefuseThePluginAndNameTheirNewWay() throws {
        let cases = [
            ("read=panel\n# global=true", "offers=search"),
            ("read=panel\n# global=rows", "offers=rows"),
            ("read=sheet\n# float=true", "offers=float"),
            ("read=60\n# tray=true", "menu bar")
        ]
        for (header, hint) in cases {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-old-\(UUID().uuidString)")
            try "#!/bin/sh\n# \(header)\n".writeScript(to: url)
            defer { try? FileManager.default.removeItem(at: url) }

            XCTAssertThrowsError(try SpotFile(file: url, id: "script"), header) { error in
                XCTAssertTrue((error as? SpotError)?.reason.contains(hint) == true, "\(header): \(error)")
            }
        }
    }

    func testReadsTheCommentLinesUnderTheFirstLine() {
        let header = SpotHeader(text: "#!/bin/sh\n# title=Morning\n#\n# Prose has no key.\n#icon=sun.max\nsay hello\n# shortcut=m\n")

        XCTAssertEqual(header.block.value("title"), "Morning")
        XCTAssertEqual(header.block.value("icon"), "sun.max")
        XCTAssertNil(header.block.value("shortcut"))
    }

    func testReadsTheCommentsOfOtherLanguages() {
        XCTAssertEqual(SpotHeader(text: "#!/usr/bin/env lua\n-- read=5\nprint(1)").block.value("read"), "5")
        XCTAssertEqual(SpotHeader(text: "#!/usr/bin/env bun\n// read=5\nconsole.log(1)").block.value("read"), "5")
    }

    func testAProgramHasNoHeader() {
        XCTAssertEqual(SpotHeader(text: "\u{7F}ELF\u{0}\u{0}\n# title=Lost").block.fields, [])
    }

    func testABlankLineEndsTheHeader() {
        XCTAssertNil(SpotHeader(text: "#!/bin/sh\n\n# title=Late\n").block.value("title"))
    }

    func testAViewIsASwiftFileBesideTheScript() throws {
        let folder = URL(fileURLWithPath: "/plugins/home")
        let header = SpotHeader(text: "#!/bin/sh\n# view=cups.swift\n").block

        let spot = try XCTUnwrap(try SpotFile(script: folder.appendingPathComponent("cups.sh"), header: header, id: "home/cups").spots.first)

        XCTAssertEqual(spot.view, "/plugins/home/cups.swift")
    }

    func testAnAnswersPatternIsTheWholeRestOfItsLine() throws {
        let header = SpotHeader(text: "#!/bin/sh\n# answers=^\\s*([0-9,.]|(?i:today|now)\\b)\n").block

        let spot = try XCTUnwrap(try SpotFile(script: URL(fileURLWithPath: "/plugins/calc.sh"), header: header, id: "calc").spots.first)

        XCTAssertEqual(spot.answers?.text, #"^\s*([0-9,.]|(?i:today|now)\b)"#)
        XCTAssertEqual(["1,5", "Today", "notes"].map { spot.answers?.matches($0) }, [true, true, false])
    }

    func testAHeaderPictureOnTheWebKeepsItsURL() throws {
        let header = SpotHeader(text: "#!/bin/sh\n# icon=https://example.com/cups.png\n").block

        let spot = try XCTUnwrap(try SpotFile(script: URL(fileURLWithPath: "/plugins/home/cups.sh"), header: header, id: "home/cups").spots.first)

        XCTAssertEqual(spot.icon, .image("https://example.com/cups.png"))
    }

    func testAViewThatIsNoSwiftFileIsRefused() {
        let header = SpotHeader(text: "#!/bin/sh\n# title=Cups\n# view=cups.txt\n").block

        XCTAssertThrowsError(try SpotFile(script: URL(fileURLWithPath: "/plugins/cups.sh"), header: header, id: "cups")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "Cups needs a Swift file for its view, such as view=cups.swift")
        }
    }

    func testAViewInATopLevelScriptIsRefusedWithTheFolderToMoveTo() {
        let header = SpotHeader(text: "#!/bin/sh\n# title=Cups\n# view=cups.swift\n").block

        XCTAssertThrowsError(try SpotFile(script: URL(fileURLWithPath: "/plugins/cups.sh"), header: header, id: "cups")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "Cups has a view, so it needs a folder of its own. Move cups.sh and cups.swift into a folder such as cups/")
        }
    }
}
