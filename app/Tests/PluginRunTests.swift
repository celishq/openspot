import XCTest
@testable import OpenspotCore

final class PluginRunTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("openspot-run-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func writePlugin(_ name: String, _ body: String) throws -> PluginCommand {
        let url = folder.appendingPathComponent(name)
        try body.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return PluginCommand(id: name, name: name, url: url)
    }

    func testReturnsWhatThePluginPrintsForTheArguments() async throws {
        let plugin = try writePlugin("echo.sh", "#!/bin/sh\necho \"$1\"\n")

        let output = try await PluginRun(command: plugin, arguments: ["hello"], timeout: 5).output()

        XCTAssertEqual(output, "hello\n")
    }

    func testGivesTheInputToThePlugin() async throws {
        let plugin = try writePlugin("cat.sh", "#!/bin/sh\ncat\n")

        let output = try await PluginRun(command: plugin, arguments: [], timeout: 5, input: "line \"one\"\nline two").output()

        XCTAssertEqual(output, "line \"one\"\nline two")
    }

    func testAPluginThatIgnoresALargeInputStillFinishes() async throws {
        let plugin = try writePlugin("quiet.sh", "#!/bin/sh\necho done\n")

        let output = try await PluginRun(command: plugin, arguments: [], timeout: 5, input: String(repeating: "x", count: 500_000)).output()

        XCTAssertEqual(output, "done\n")
    }

    func testARunGetsTheDataFolderAndOpenspotCreatesIt() async throws {
        let config = folder.appendingPathComponent("config")
        setenv("OPENSPOT_CONFIG", config.path, 1)
        defer { unsetenv("OPENSPOT_CONFIG") }
        let plugin = try writePlugin("data.sh", "#!/bin/sh\nprintf %s \"$OPENSPOT_DATA\"\n")
        let data = config.appendingPathComponent("data").path

        let output = try await PluginRun(command: plugin, arguments: [], timeout: 5).output()

        XCTAssertEqual(output, data)
        var isFolder: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: data, isDirectory: &isFolder))
        XCTAssertTrue(isFolder.boolValue)
    }

    func testTheDataFolderIsInTheHomeOfTheRunWithNoConfigPath() {
        let environment = PluginRun.environment(base: ["HOME": folder.path], app: "")

        XCTAssertEqual(environment["OPENSPOT_DATA"], folder.appendingPathComponent(".config/openspot/data").path)
    }

    func testTimesOutASlowPlugin() async throws {
        let plugin = try writePlugin("slow.sh", "#!/bin/sh\nsleep 5\n")

        do {
            _ = try await PluginRun(command: plugin, arguments: [], timeout: 0.5).output()
            XCTFail("expected a timeout")
        } catch PluginError.timedOut {
        }
    }
}
