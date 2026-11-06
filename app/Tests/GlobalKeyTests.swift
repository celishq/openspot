import XCTest
@testable import OpenspotCore

final class GlobalKeyTests: XCTestCase {
    private func command(header: String) throws -> PluginCommand {
        let block = PluginHeader(text: "#!/bin/sh\n\(header)\n").block
        let plugin = try Plugin(script: URL(fileURLWithPath: "/plugins/move.sh"), header: block, id: "move")
        return try XCTUnwrap(plugin.commands.first)
    }

    func testAHeaderHoldsOneKeyOnEachLine() throws {
        let keys = try command(header: "# global=ctrl+option+up full\n# global=ctrl+option+down center").globalKeys

        XCTAssertEqual(keys.map(\.shortcut.text), ["ctrl+option+up", "ctrl+option+down"])
        XCTAssertEqual(keys.map(\.call), ["full", "center"])
        XCTAssertEqual(keys.map(\.spot), ["move", "move"])
    }

    func testAScriptWithNoLineHoldsNoKey() throws {
        XCTAssertEqual(try command(header: "# name=Move").globalKeys, [])
    }

    func testABadLineRefusesThePluginAndNamesTheFault() {
        for line in ["# global=ctrl+option+up", "# global=up full", "# global=ctrl+up read", "# global=ctrl+up full now"] {
            XCTAssertThrowsError(try command(header: line), line) { error in
                XCTAssertTrue((error as? PluginError)?.reason.contains("unknown global") == true, line)
            }
        }
    }

    func testAScanListsTheKeysOfEachScript() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-global-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "#!/bin/sh\n# global=ctrl+up full\n".writeScript(to: folder.appendingPathComponent("move.sh"))

        XCTAssertEqual(try PluginFolder(url: folder).scan().globalKeys.map(\.call), ["full"])
    }
}
