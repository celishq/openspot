import XCTest
@testable import OpenspotCore

final class PluginHeaderTests: XCTestCase {
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
}
