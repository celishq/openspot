import XCTest
@testable import OpenspotCore

final class PluginHeaderTests: XCTestCase {
    func testReadsNameAndApi() {
        let header = PluginHeader(text: "#!/bin/sh\n# @name Links\n# @api 1\necho hi\n")
        XCTAssertEqual(header?.name, "Links")
        XCTAssertEqual(header?.api, 1)
    }

    func testMissingNameGivesNoHeader() {
        XCTAssertNil(PluginHeader(text: "#!/bin/sh\n# @api 1\n"))
    }
}
