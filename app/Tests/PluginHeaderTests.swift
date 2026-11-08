import XCTest
@testable import OpenspotCore

final class PluginHeaderTests: XCTestCase {
    func testAScriptWithCommandsHasNoCardOnTheGridAndStaysInTheScan() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-grid-\(UUID().uuidString)")
        try Data("#!/bin/sh\n# command=left:Left side\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        defer { try? FileManager.default.removeItem(at: url) }

        let command = try XCTUnwrap(try Plugin(file: url, id: "script")?.commands.first)

        XCTAssertFalse(command.headerState.isOnGrid)
        XCTAssertTrue(command.hasSpot)
    }

    func testAGlobalScriptWithNoKeyHasNoCardOnTheGrid() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-grid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let searchOnly = folder.appendingPathComponent("search.sh"), keyed = folder.appendingPathComponent("keyed.sh")
        try "#!/bin/sh\n# read=panel\n# global=true\n".writeScript(to: searchOnly)
        try "#!/bin/sh\n# read=panel\n# global=true\n# key=k\n".writeScript(to: keyed)

        XCTAssertFalse(try XCTUnwrap(try Plugin(file: searchOnly, id: "search")?.commands.first).headerState.isOnGrid)
        XCTAssertTrue(try XCTUnwrap(try Plugin(file: keyed, id: "keyed")?.commands.first).headerState.isOnGrid)
    }

    func testReadsTheCommentLinesUnderTheFirstLine() {
        let header = PluginHeader(text: "#!/bin/sh\n# name=Morning\n#\n# Prose has no key.\n#symbol=sun.max\nsay hello\n# key=m\n")

        XCTAssertEqual(header.block.value("name"), "Morning")
        XCTAssertEqual(header.block.value("symbol"), "sun.max")
        XCTAssertNil(header.block.value("key"))
    }

    func testReadsTheCommentsOfOtherLanguages() {
        XCTAssertEqual(PluginHeader(text: "#!/usr/bin/env lua\n-- read=5\nprint(1)").block.value("read"), "5")
        XCTAssertEqual(PluginHeader(text: "#!/usr/bin/env bun\n// read=5\nconsole.log(1)").block.value("read"), "5")
    }

    func testAProgramHasNoHeader() {
        XCTAssertEqual(PluginHeader(text: "\u{7F}ELF\u{0}\u{0}\n# name=Lost").block.fields, [])
    }

    func testABlankLineEndsTheHeader() {
        XCTAssertNil(PluginHeader(text: "#!/bin/sh\n\n# name=Late\n").block.value("name"))
    }

    func testAViewIsASwiftFileBesideTheScript() throws {
        let folder = URL(fileURLWithPath: "/plugins/home")
        let header = PluginHeader(text: "#!/bin/sh\n# view=cups.swift\n").block

        let spot = try XCTUnwrap(try Plugin(script: folder.appendingPathComponent("cups.sh"), header: header, id: "home/cups").commands.first)

        XCTAssertEqual(spot.view, "/plugins/home/cups.swift")
    }

    func testAViewThatIsNoSwiftFileIsRefused() {
        let header = PluginHeader(text: "#!/bin/sh\n# name=Cups\n# view=cups.txt\n").block

        XCTAssertThrowsError(try Plugin(script: URL(fileURLWithPath: "/plugins/cups.sh"), header: header, id: "cups")) { error in
            XCTAssertEqual((error as? PluginError)?.reason, "Cups needs a Swift file for its view, such as view=cups.swift")
        }
    }

    func testAViewInATopLevelScriptIsRefusedWithTheFolderToMoveTo() {
        let header = PluginHeader(text: "#!/bin/sh\n# name=Cups\n# view=cups.swift\n").block

        XCTAssertThrowsError(try Plugin(script: URL(fileURLWithPath: "/plugins/cups.sh"), header: header, id: "cups")) { error in
            XCTAssertEqual((error as? PluginError)?.reason, "Cups has a view, so it needs a folder of its own. Move cups.sh and cups.swift into a folder such as cups/")
        }
    }
}
