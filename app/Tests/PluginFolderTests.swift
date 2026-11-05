import XCTest
@testable import OpenspotCore

final class PluginFolderTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("openspot-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func writePlugin(_ name: String, manifest: String, files: [String] = ["run.sh"]) throws {
        let plugin = folder.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: plugin, withIntermediateDirectories: true)
        try manifest.write(to: plugin.appendingPathComponent("manifest.toml"), atomically: true, encoding: .utf8)
        for file in files {
            let url = plugin.appendingPathComponent(file)
            try "#!/bin/sh\n".write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }

    private func manifest(api: Int = 1, command: String = "") -> String {
        """
        name = "Tools"
        api = \(api)

        [[commands]]
        name = "One"
        exec = "run.sh"
        \(command)
        """
    }

    func testReadsEveryCommandOfAPlugin() throws {
        try writePlugin("tools", manifest: """
        name = "Tools"
        api = 1

        [[commands]]
        name = "One"
        exec = "one.sh"
        type = "toggle"
        size = "square"
        symbol = "moon"
        subtitle = "Off"
        key = "o"

        [[commands]]
        name = "Two"
        exec = "two.sh"
        """, files: ["one.sh", "two.sh"])

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.refused, [])
        XCTAssertEqual(scan.plugins.map(\.name), ["Tools"])
        XCTAssertEqual(scan.commands.map(\.name), ["One", "Two"])
        let one = scan.commands[0]
        XCTAssertEqual(one.kind, .toggle)
        XCTAssertEqual(one.size, .square)
        XCTAssertEqual(one.symbol, "moon")
        XCTAssertEqual(one.subtitle, "Off")
        XCTAssertEqual(one.key?.name, "o")
        XCTAssertEqual(one.url.lastPathComponent, "one.sh")
    }

    func testAListReadsHowItBehaves() throws {
        try writePlugin("tools", manifest: """
        name = "Tools"
        api = 1

        [[commands]]
        name = "One"
        exec = "one.sh"
        type = "list"
        state = true
        pick = "stay"
        global = true
        """, files: ["one.sh"])

        let command = try XCTUnwrap(try PluginFolder(url: folder).scan().commands.first)

        XCTAssertEqual(command.kind, .list)
        XCTAssertTrue(command.hasState)
        XCTAssertEqual(command.pick, .stay)
        XCTAssertTrue(command.isGlobal)
    }

    func testAPickThatIsNotKnownRefusesThePlugin() throws {
        try writePlugin("tools", manifest: """
        name = "Tools"
        api = 1

        [[commands]]
        name = "One"
        exec = "one.sh"
        pick = "later"
        """, files: ["one.sh"])

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.plugins, [])
        XCTAssertEqual(scan.refused.first?.reason, "One has an unknown pick: later")
    }

    func testACommandWithNoLookIsAWideLaunchSpot() throws {
        try writePlugin("tools", manifest: manifest())

        let command = try XCTUnwrap(try PluginFolder(url: folder).scan().commands.first)

        XCTAssertEqual(command.kind, .launch)
        XCTAssertEqual(command.size, .wide)
        XCTAssertEqual(command.symbol, "app")
        XCTAssertNil(command.key)
        XCTAssertFalse(command.hasState)
        XCTAssertEqual(command.pick, .close)
        XCTAssertFalse(command.isGlobal)
    }

    func testCommandsOfTwoPluginsHaveDifferentIds() throws {
        try writePlugin("a", manifest: manifest())
        try writePlugin("b", manifest: manifest())

        let ids = try PluginFolder(url: folder).scan().commands.map(\.id)

        XCTAssertEqual(ids, ["a/One", "b/One"])
    }

    func testSkipsAFolderWithNoManifestAndAFile() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("empty"), withIntermediateDirectories: true)
        try "text".write(to: folder.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.plugins, [])
        XCTAssertEqual(scan.refused, [])
    }

    func testRefusesAnUnknownApi() throws {
        try writePlugin("future", manifest: manifest(api: 9))

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.plugins, [])
        XCTAssertEqual(scan.refused, [Refusal(file: "future", reason: "needs api 9")])
    }

    func testRefusesAManifestWithAFault() throws {
        try writePlugin("a", manifest: manifest(command: "type = \"dial\""))
        try writePlugin("b", manifest: manifest(command: "size = \"huge\""))
        try writePlugin("c", manifest: manifest(command: "key = \"ctrl+d\""))
        try writePlugin("d", manifest: "name = \"D\"\napi = 1\n\n[[commands]]\nname = \"One\"\nexec = \"gone.sh\"\n")
        try writePlugin("e", manifest: "api = 1\n")

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.refused, [
            Refusal(file: "a", reason: "One has an unknown type: dial"),
            Refusal(file: "b", reason: "One has an unknown size: huge"),
            Refusal(file: "c", reason: "One has an unknown key: ctrl+d"),
            Refusal(file: "d", reason: "One needs a file named gone.sh"),
            Refusal(file: "e", reason: "needs a name")
        ])
    }

    func testTheFirstCommandKeepsATakenKey() throws {
        try writePlugin("a", manifest: manifest(command: "key = \"d\""))
        try writePlugin("b", manifest: manifest(command: "key = \"D\""))

        let scan = try PluginFolder(url: folder).scan()

        XCTAssertEqual(scan.commands.map(\.key?.name), ["d", nil])
        XCTAssertEqual(scan.refused, [Refusal(file: "b", reason: "One cannot use key d, because another command has it")])
    }
}
